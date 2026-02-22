local util = require("claude-code.util")

local M = {}

--- @type table<string, function>
local handlers = {}

--- Register a method handler
--- @param method string
--- @param handler function(params: table, id: string|number|nil): table|nil
function M.register_handler(method, handler)
  handlers[method] = handler
  util.log_debug("Registered MCP handler: %s", method)
end

--- Handle an incoming JSON-RPC 2.0 message
--- @param json_string string
--- @return string|nil response JSON string, or nil for notifications
function M.handle_message(json_string)
  local ok, msg = pcall(vim.json.decode, json_string)
  if not ok or type(msg) ~= "table" then
    util.log_warn("Failed to parse JSON-RPC message")
    return vim.json.encode({
      jsonrpc = "2.0",
      id = vim.NIL,
      error = { code = -32700, message = "Parse error" },
    })
  end

  local method = msg.method
  local id = msg.id
  local params = msg.params or {}

  -- Notification (no id): dispatch and return nil
  if id == nil then
    local handler = handlers[method]
    if handler then
      local success, err = pcall(handler, params, nil)
      if not success then
        util.log_error("Notification handler error (%s): %s", method, tostring(err))
      end
    else
      util.log_debug("No handler for notification: %s", tostring(method))
    end
    return nil
  end

  -- Request (has id): dispatch and return response
  local handler = handlers[method]
  if not handler then
    util.log_warn("Method not found: %s", tostring(method))
    return vim.json.encode({
      jsonrpc = "2.0",
      id = id,
      error = { code = -32601, message = "Method not found: " .. tostring(method) },
    })
  end

  local success, result = pcall(handler, params, id)
  if not success then
    util.log_error("Handler error (%s): %s", method, tostring(result))
    return vim.json.encode({
      jsonrpc = "2.0",
      id = id,
      error = { code = -32603, message = "Internal error: " .. tostring(result) },
    })
  end

  return vim.json.encode({
    jsonrpc = "2.0",
    id = id,
    result = result,
  })
end

--- Build a JSON-RPC 2.0 notification
--- @param method string
--- @param params table|nil
--- @return string
function M.build_notification(method, params)
  return vim.json.encode({
    jsonrpc = "2.0",
    method = method,
    params = params or vim.empty_dict(),
  })
end

--- Register default MCP handlers for Phase 0
function M.register_defaults()
  -- initialize
  M.register_handler("initialize", function(params, _id)
    util.log_info("MCP initialize from: %s", vim.inspect(params.clientInfo or {}))
    return {
      protocolVersion = "2025-03-26",
      capabilities = {
        tools = vim.empty_dict(),
      },
      serverInfo = {
        name = "Claude Code Neovim MCP",
        version = "0.1.0",
      },
    }
  end)

  -- notifications/initialized
  M.register_handler("notifications/initialized", function(_params, _id)
    util.log_info("MCP initialized notification received")
  end)

  -- tools/list
  M.register_handler("tools/list", function(_params, _id)
    return {
      tools = {},
    }
  end)

  -- notifications/cancelled
  M.register_handler("notifications/cancelled", function(params, _id)
    util.log_debug("Request cancelled: %s", tostring(params.requestId))
  end)

  -- ide_connected (sent by Claude CLI after WebSocket connection)
  M.register_handler("ide_connected", function(params, _id)
    util.log_info("Claude CLI connected (pid: %s)", tostring(params.pid))
  end)
end

return M
