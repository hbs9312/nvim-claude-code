# Phase 3-03: User Autocmd Emission

## Status: ✅ Complete

## Purpose

Emit key plugin events as Neovim User autocmds, allowing users to register their own hooks and execute custom logic.

## Dependencies

- [x] Phase 0: Foundation Infrastructure (Complete)
- [ ] Phase 1: Core Tools (Required, Incomplete)
- [ ] Phase 2: Auxiliary Tools (Required, Incomplete)

## Input

Internal events:
- Server start/stop
- Client connect/disconnect
- Diff accept/reject

## Output

User autocmd emission:

| Event | pattern | data |
|-------|---------|------|
| Server started | `ClaudeCodeServerStarted` | `{port}` |
| Server stopped | `ClaudeCodeServerStopped` | `{}` |
| Client connected | `ClaudeCodeClientConnected` | `{clientInfo}` |
| Client disconnected | `ClaudeCodeClientDisconnected` | `{}` |
| Diff accepted | `ClaudeCodeDiffAccepted` | `{filePath}` |
| Diff rejected | `ClaudeCodeDiffRejected` | `{filePath}` |

## Implementation Plan

1. **Event emission utility**
   - Implement a common event emission function
   ```lua
   local function emit(pattern, data)
     vim.api.nvim_exec_autocmds("User", {
       pattern = pattern,
       data = data,
     })
   end
   ```

2. **Event insertion points**
   - After server startup completes: `emit("ClaudeCodeServerStarted", {port = port})`
   - After server shutdown: `emit("ClaudeCodeServerStopped", {})`
   - On WebSocket client connection: `emit("ClaudeCodeClientConnected", {clientInfo = info})`
   - On WebSocket client disconnection: `emit("ClaudeCodeClientDisconnected", {})`
   - After diff accept: `emit("ClaudeCodeDiffAccepted", {filePath = path})`
   - After diff reject: `emit("ClaudeCodeDiffRejected", {filePath = path})`

3. **User usage example**
   ```lua
   vim.api.nvim_create_autocmd("User", {
     pattern = "ClaudeCodeDiffAccepted",
     callback = function(ev)
       vim.notify("Diff accepted: " .. ev.data.filePath)
     end,
   })
   ```

## Verification Criteria

- [ ] Each event is emitted at the appropriate time
- [ ] The data field contains the correct information
- [ ] User-registered callbacks work correctly
- [ ] No errors occur during event emission (callback errors are also isolated)
- [ ] Works without errors even when no callbacks are registered

## Reference Specs

- `07-plugin-api.md` Section 7.4

## Estimated Time: ~1.5 hours
