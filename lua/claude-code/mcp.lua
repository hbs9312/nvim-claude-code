local util = require("claude-code.util")
local tools = require("claude-code.tools")

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

--- @type table<string|number, fun(result: table)> Pending deferred response callbacks
local deferred = {}

--- Defer the response for a request (for blocking tools like openDiff).
--- The tool handler should call this and later invoke the callback to send the response.
--- @param id string|number request id
--- @param callback fun(send: fun(result: table)) called immediately with a send function
function M.defer_response(id, callback)
  -- callback receives a "send" function that must be called exactly once
  deferred[id] = true
  callback(function(result)
    deferred[id] = nil
    local server = require("claude-code.server")
    server.send_text(vim.json.encode({
      jsonrpc = "2.0",
      id = id,
      result = result,
    }))
  end)
end

--- Check if a request id has a deferred response pending
--- @param id string|number
--- @return boolean
function M.is_deferred(id)
  return deferred[id] ~= nil
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

  -- nil result means the response is deferred (e.g., blocking tool like openDiff)
  if result == nil then
    return nil
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

  -- tools/list — return all registered tools from the tool registry
  M.register_handler("tools/list", function(_params, _id)
    return {
      tools = tools.list(),
    }
  end)

  -- tools/call — dispatch to the tool registry
  -- Returns result synchronously, or nil if the tool defers its response.
  M.register_handler("tools/call", function(params, id)
    local name = params.name
    local arguments = params.arguments or {}

    if not tools.has(name) then
      return {
        content = { { type = "text", text = "Unknown tool: " .. tostring(name) } },
        isError = true,
      }
    end

    local ok, result = pcall(tools.call, name, arguments, id)
    if not ok then
      util.log_error("Tool call error (%s): %s", name, tostring(result))
      return {
        content = { { type = "text", text = "Tool error: " .. tostring(result) } },
        isError = true,
      }
    end

    -- nil result means the tool has deferred its response (e.g., openDiff waiting for accept/reject)
    if result == nil then
      return nil
    end

    return result
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
