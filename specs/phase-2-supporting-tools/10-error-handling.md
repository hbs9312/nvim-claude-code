# Phase 2-10: pcall Wrapper, Error Recovery

## Status: Pending

## Purpose

Strengthen error handling across the entire plugin. Wrap all tool handlers with `pcall`, implement WebSocket error recovery and reconnection handling so that Neovim never crashes under any circumstances.

## Dependencies

- [x] Phase 0: Foundation Infrastructure (complete)
- [ ] Phase 1: Core Tools (required, incomplete)
  - It is most efficient to wrap error handling after all tools are implemented

## Input

All paths where errors can occur:

- MCP tool execution (tools/call handlers)
- WebSocket message reception/parsing
- WebSocket connection drops
- Neovim API call failures (buffer deleted, window closed, etc.)
- JSON encoding/decoding failures
- File I/O failures

## Output

- **Tool errors**: JSON-RPC error response (`error.code`, `error.message`)
- **WebSocket errors**: Reconnection attempt or graceful shutdown
- **General errors**: `vim.notify` warning + log entry
- **All cases**: Neovim continues to function normally (no crashes)

## Implementation Plan

### File Location

- Error wrapper: `lua/claude-code/util.lua` or `lua/claude-code/error.lua`
- Applies to: `mcp.lua`, `server.lua`, `websocket.lua`, `tools/*.lua`

### 1. Tool Handler pcall Wrapper

A general-purpose wrapper that wraps all tool executions with pcall:

```lua
-- lua/claude-code/mcp.lua (tools/call handler)
local function handle_tools_call(request)
  local tool_name = request.params.name
  local arguments = request.params.arguments or {}

  local handler = registry.get_handler(tool_name)
  if not handler then
    return json_rpc_error(request.id, -32601, "Tool not found: " .. tool_name)
  end

  -- Wrap tool execution with pcall
  local ok, result = pcall(handler, arguments)
  if not ok then
    log.error("Tool error [" .. tool_name .. "]: " .. tostring(result))
    return json_rpc_error(request.id, -32603, "Internal error: " .. tostring(result))
  end

  return json_rpc_result(request.id, result)
end
```

### 2. JSON-RPC Error Response Utility

```lua
local ERROR_CODES = {
  PARSE_ERROR = -32700,
  INVALID_REQUEST = -32600,
  METHOD_NOT_FOUND = -32601,
  INVALID_PARAMS = -32602,
  INTERNAL_ERROR = -32603,
}

local function json_rpc_error(id, code, message)
  return {
    jsonrpc = "2.0",
    id = id,
    error = {
      code = code,
      message = message,
    },
  }
end
```

### 3. WebSocket Error Recovery

```lua
-- websocket.lua
local function on_data(client, data)
  local ok, err = pcall(function()
    local frames = parse_frames(data)
    for _, frame in ipairs(frames) do
      handle_frame(client, frame)
    end
  end)

  if not ok then
    log.error("WebSocket data error: " .. tostring(err))
    -- Clean up connection (prevent crash)
    pcall(function() client:close() end)
  end
end

-- Connection drop detection and state cleanup
local function on_disconnect(client)
  pcall(function()
    -- Send error responses to pending blocking requests
    resolve_pending_requests(client, "Connection lost")
    -- Clean up client state
    cleanup_client(client)
    -- Fire User autocmd
    vim.schedule(function()
      vim.api.nvim_exec_autocmds("User", {
        pattern = "ClaudeCodeClientDisconnected",
      })
    end)
  end)
end
```

### 4. vim.schedule Wrapper

Since Neovim APIs can only be called from the main thread, provide a safe wrapper:

```lua
local function safe_schedule(fn)
  vim.schedule(function()
    local ok, err = pcall(fn)
    if not ok then
      log.error("Scheduled callback error: " .. tostring(err))
    end
  end)
end
```

### 5. Error Recovery Strategy

| Error Type | Recovery Strategy |
|------------|-------------------|
| Tool handler error | Return JSON-RPC error response, log the error |
| JSON parse error | Return Parse error (-32700) response, maintain connection |
| WebSocket frame error | Ignore the message, maintain connection |
| WebSocket connection drop | Clean up state, release pending requests, fire User autocmd |
| Buffer/window deleted | Ignore the operation, return appropriate error message |
| File I/O failure | Return failure response with error message |
| Neovim API error | Handle with pcall, log the error |

### 6. Blocking Request Timeout

To prevent blocking tools like openDiff from waiting indefinitely:

```lua
-- Optional: timeout setting (disabled by default)
local BLOCKING_TIMEOUT_MS = nil  -- nil = no timeout (wait for user)

-- Release all pending requests on connection drop
local function resolve_pending_requests(client, error_message)
  for id, pending in pairs(client.pending) do
    pending.callback(json_rpc_error(id, -32603, error_message))
  end
  client.pending = {}
end
```

## Acceptance Criteria

- [ ] All tool handler errors return a JSON-RPC error response (no crashes)
- [ ] Invalid JSON received returns a Parse error response, connection is maintained
- [ ] Unsupported method calls return a Method not found response
- [ ] On WebSocket connection drop, pending requests are released and state is cleaned up
- [ ] Client reconnection works normally (no interference from previous state)
- [ ] Accessing deleted buffers/windows is handled without error
- [ ] All errors are recorded in logs
- [ ] Neovim does not crash under any error condition

## Reference Specs

- [03-mcp-protocol.md section 3.5](../03-mcp-protocol.md) - JSON-RPC error codes (-32700 ~ -32603)
- [03-mcp-protocol.md section 3.3](../03-mcp-protocol.md) - Error response structure

## Estimated Time: ~2 hours
