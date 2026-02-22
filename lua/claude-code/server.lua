local util = require("claude-code.util")
local websocket = require("claude-code.websocket")
local mcp = require("claude-code.mcp")

local uv = vim.uv or vim.loop

local M = {}

--- @class ServerState
--- @field tcp_server userdata|nil
--- @field port number|nil
--- @field auth_token string|nil
--- @field client userdata|nil
--- @field client_buf string
--- @field handshake_done boolean
--- @field ping_timer userdata|nil
--- @field config table|nil

--- @type ServerState
local state = {
  tcp_server = nil,
  port = nil,
  auth_token = nil,
  client = nil,
  client_buf = "",
  handshake_done = false,
  ping_timer = nil,
  config = nil,
}

--- Send data to the connected client
--- @param data string
local function send_to_client(data)
  if state.client and not state.client:is_closing() then
    state.client:write(data)
  end
end

--- Send a WebSocket text frame to the client
--- @param text string
function M.send_text(text)
  send_to_client(websocket.create_text_frame(text))
end

--- Send an MCP notification to the client
--- @param method string
--- @param params table|nil
function M.send_notification(method, params)
  local json = mcp.build_notification(method, params)
  M.send_text(json)
end

--- Close the current client connection
--- @param code number|nil WebSocket close code
--- @param reason string|nil
local function close_client(code, reason)
  if not state.client then return end

  if not state.client:is_closing() then
    -- Send close frame
    local frame = websocket.create_close_frame(code, reason)
    state.client:write(frame, function()
      if state.client and not state.client:is_closing() then
        state.client:shutdown()
        state.client:close()
      end
    end)
  end

  state.client = nil
  state.client_buf = ""
  state.handshake_done = false
  util.log_info("Client disconnected")
end

--- Process received data in WebSocket mode (after handshake)
--- @param data string
local function process_websocket_data(data)
  state.client_buf = state.client_buf .. data

  while #state.client_buf > 0 do
    local frame, consumed = websocket.parse_frame(state.client_buf)
    if not frame then
      break -- need more data
    end

    state.client_buf = state.client_buf:sub(consumed + 1)

    if frame.opcode == websocket.OPCODE.TEXT then
      -- JSON-RPC message — dispatch on main thread
      local payload = frame.payload
      vim.schedule(function()
        local response = mcp.handle_message(payload)
        if response then
          M.send_text(response)
        end
      end)
    elseif frame.opcode == websocket.OPCODE.PING then
      send_to_client(websocket.create_pong_frame(frame.payload))
    elseif frame.opcode == websocket.OPCODE.PONG then
      util.log_debug("Pong received")
    elseif frame.opcode == websocket.OPCODE.CLOSE then
      util.log_info("Client sent close frame")
      -- Echo close frame back
      send_to_client(websocket.create_close_frame(1000))
      close_client()
    end
  end
end

--- Process received data in HTTP mode (before handshake)
--- @param data string
local function process_http_data(data)
  state.client_buf = state.client_buf .. data

  -- Check if we have a complete HTTP request (ends with \r\n\r\n)
  if not state.client_buf:find("\r\n\r\n") then
    return
  end

  local request = state.client_buf
  state.client_buf = ""

  local ok, result = websocket.validate_upgrade(request, state.auth_token)
  if not ok then
    util.log_warn("WebSocket upgrade failed: %s", tostring(result))
    send_to_client(websocket.create_forbidden_response())
    close_client()
    return
  end

  -- Successful upgrade
  local headers = result
  local client_key = headers["sec-websocket-key"]
  local response = websocket.create_upgrade_response(client_key)
  send_to_client(response)

  state.handshake_done = true
  util.log_info("WebSocket handshake completed")
end

--- Handle incoming data from a client
--- @param err string|nil
--- @param data string|nil
local function on_data(err, data)
  if err then
    util.log_error("Read error: %s", err)
    close_client()
    return
  end

  if not data then
    -- EOF
    util.log_info("Client connection closed (EOF)")
    close_client()
    return
  end

  if state.handshake_done then
    process_websocket_data(data)
  else
    process_http_data(data)
  end
end

--- Handle a new incoming connection
--- @param err string|nil
local function on_new_connection(err)
  if err then
    util.log_error("Connection error: %s", err)
    return
  end

  local client = uv.new_tcp()
  state.tcp_server:accept(client)

  -- Single client policy: close existing connection
  if state.client then
    util.log_info("New connection — closing previous client")
    close_client(1000, "New connection")
  end

  state.client = client
  state.client_buf = ""
  state.handshake_done = false

  util.log_info("New client connected")
  client:read_start(on_data)
end

--- Start ping keepalive timer (30s interval)
local function start_ping_timer()
  if state.ping_timer then return end

  state.ping_timer = uv.new_timer()
  state.ping_timer:start(30000, 30000, function()
    if state.client and state.handshake_done then
      send_to_client(websocket.create_ping_frame())
    end
  end)
end

--- Stop ping timer
local function stop_ping_timer()
  if state.ping_timer then
    if not state.ping_timer:is_closing() then
      state.ping_timer:stop()
      state.ping_timer:close()
    end
    state.ping_timer = nil
  end
end

--- Start the WebSocket server
--- @param config table
--- @param auth_token string
--- @return number|nil port, or nil on failure
function M.start(config, auth_token)
  if state.tcp_server then
    util.log_warn("Server already running on port %d", state.port or 0)
    return state.port
  end

  state.config = config
  state.auth_token = auth_token

  local server = uv.new_tcp()
  local ok, bind_err = server:bind(config.server.host, 0)
  if not ok then
    util.log_error("Failed to bind: %s", tostring(bind_err))
    server:close()
    return nil
  end

  local addr = server:getsockname()
  local port = addr.port

  -- Validate port is in acceptable range
  local range = config.server.port_range
  if port < range[1] or port > range[2] then
    util.log_warn("OS assigned port %d outside configured range %d-%d, using it anyway", port, range[1], range[2])
  end

  local listen_ok, listen_err = server:listen(1, on_new_connection)
  if not listen_ok then
    util.log_error("Failed to listen: %s", tostring(listen_err))
    server:close()
    return nil
  end

  state.tcp_server = server
  state.port = port

  start_ping_timer()

  util.log_info("Server started on %s:%d", config.server.host, port)
  return port
end

--- Stop the server and clean up all resources
function M.stop()
  stop_ping_timer()

  -- Close client
  if state.client then
    close_client(1000, "Server shutting down")
  end

  -- Close server
  if state.tcp_server then
    if not state.tcp_server:is_closing() then
      state.tcp_server:close()
    end
    state.tcp_server = nil
    util.log_info("Server stopped (port %d)", state.port or 0)
  end

  state.port = nil
  state.auth_token = nil
end

--- Check if server is running
--- @return boolean
function M.is_running()
  return state.tcp_server ~= nil
end

--- Get the server port
--- @return number|nil
function M.get_port()
  return state.port
end

--- Check if a client is connected and handshake is done
--- @return boolean
function M.is_client_connected()
  return state.client ~= nil and state.handshake_done
end

--- Disconnect the current client
function M.disconnect_client()
  if state.client then
    close_client(1000, "Disconnected by user")
  end
end

return M
