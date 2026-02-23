# Phase 2-09: :ClaudeCodeStatus/Stop/Restart Command Enhancement

## Status: ✅ Complete

## Purpose

Implement server status query (`:ClaudeCodeStatus`), shutdown (`:ClaudeCodeStop`), and restart (`:ClaudeCodeRestart`) commands so users can check and control the plugin's state.

## Dependencies

- [x] Phase 0: Foundation Infrastructure (complete)
  - Server base behavior (TCP server, WebSocket, Lock file)

## Input

The user executes each command:

- `:ClaudeCodeStatus` - Query status
- `:ClaudeCodeStop` - Stop server
- `:ClaudeCodeRestart` - Restart server

## Output

### :ClaudeCodeStatus

```
Claude Code MCP Server
  Status:     running
  Port:       12345
  Auth:       configured
  Client:     connected (Claude CLI v1.x.x)
  Uptime:     5m 32s
  Tools:      12 registered
```

When no client is connected:

```
Claude Code MCP Server
  Status:     running
  Port:       12345
  Auth:       configured
  Client:     not connected
  Uptime:     2m 10s
  Tools:      12 registered
```

When the server is stopped:

```
Claude Code MCP Server
  Status:     stopped
```

### :ClaudeCodeStop

```
Claude Code: Server stopped
```

### :ClaudeCodeRestart

```
Claude Code: Server restarted on port 12345
```

## Implementation Plan

### File Location

- Command registration: `lua/claude-code/init.lua` or `lua/claude-code/commands.lua`
- Server control: `lua/claude-code/server.lua` (existing)

### Implementation Steps

#### :ClaudeCodeStatus

1. Check server running state (`server.is_running()`)
2. Query port number (`server.get_port()`)
3. Check authentication configuration state
4. Query client connection state and information (`server.get_client_info()`)
5. Calculate uptime from server start time
6. Query the number of registered tools
7. Output as formatted string via `vim.notify` or echo

#### :ClaudeCodeStop

1. Check server running state
2. Notify connected client of shutdown (optional)
3. Disconnect WebSocket connection
4. Shut down TCP server
5. Delete Lock file
6. Clean up resources (timers, autocmds, etc.)
7. Update state

#### :ClaudeCodeRestart

1. Execute `:ClaudeCodeStop`
2. After a brief delay, restart the server (`server.start()`)
3. Assign new port, recreate Lock file
4. Output status

### Pseudocode

```lua
-- :ClaudeCodeStatus
vim.api.nvim_create_user_command("ClaudeCodeStatus", function()
  local server = require("claude-code.server")
  local registry = require("claude-code.tools")

  if not server.is_running() then
    vim.notify("Claude Code MCP Server\n  Status:     stopped", vim.log.levels.INFO)
    return
  end

  local info = server.get_connection_info()
  local client_str = info.connected
    and string.format("connected (%s)", info.clientInfo or "unknown")
    or "not connected"

  local lines = {
    "Claude Code MCP Server",
    "  Status:     running",
    "  Port:       " .. info.port,
    "  Auth:       configured",
    "  Client:     " .. client_str,
    "  Uptime:     " .. server.get_uptime_str(),
    "  Tools:      " .. registry.count() .. " registered",
  }

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end, {})

-- :ClaudeCodeStop
vim.api.nvim_create_user_command("ClaudeCodeStop", function()
  local server = require("claude-code.server")
  if not server.is_running() then
    vim.notify("Claude Code: Server is not running", vim.log.levels.WARN)
    return
  end
  server.stop()
  vim.notify("Claude Code: Server stopped", vim.log.levels.INFO)
end, {})

-- :ClaudeCodeRestart
vim.api.nvim_create_user_command("ClaudeCodeRestart", function()
  local server = require("claude-code.server")
  server.stop()
  vim.defer_fn(function()
    server.start()
    local port = server.get_port()
    vim.notify("Claude Code: Server restarted on port " .. port, vim.log.levels.INFO)
  end, 100)  -- Wait 100ms before restarting
end, {})
```

### Required server.lua API

| Function | Returns | Description |
|----------|---------|-------------|
| `server.is_running()` | boolean | Server running state |
| `server.get_port()` | number/nil | Current port |
| `server.get_connection_info()` | table | Connection information |
| `server.get_uptime_str()` | string | Uptime string |
| `server.stop()` | void | Stop server + clean up resources |
| `server.start()` | void | Start server |

### Resource Cleanup Checklist (:ClaudeCodeStop)

- [ ] Disconnect WebSocket connection
- [ ] Close TCP server socket
- [ ] Delete Lock file
- [ ] Clean up debounce timers
- [ ] Delete autocmd groups (selection_changed, diagnostics_changed, etc.)
- [ ] Clean up diff sessions
- [ ] Fire User autocmd (`ClaudeCodeServerStopped`)

## Acceptance Criteria

- [ ] `:ClaudeCodeStatus` accurately displays the current state
- [ ] Connected client information (version, etc.) is displayed
- [ ] Appropriate message is shown when the server is stopped
- [ ] All resources are cleaned up after `:ClaudeCodeStop`
- [ ] Lock file is deleted after `:ClaudeCodeStop`
- [ ] Server starts on a new port after `:ClaudeCodeRestart`
- [ ] Lock file is recreated with new information after `:ClaudeCodeRestart`
- [ ] Stop/Restart calls are handled without error when the server is already stopped

## Reference Specs

- [07-plugin-api.md section 7.2](../07-plugin-api.md) - User commands (:ClaudeCodeStatus, :ClaudeCodeStop, :ClaudeCodeRestart)
- [07-plugin-api.md section 7.3](../07-plugin-api.md) - Lua API (start, stop, restart, is_running, get_port, get_connection_info)
- [07-plugin-api.md section 7.4](../07-plugin-api.md) - Events (ClaudeCodeServerStopped)

## Estimated Time: ~1.5 hours
