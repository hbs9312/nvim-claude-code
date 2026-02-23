# Phase 2-08: diagnostics_changed Notification

## Status: ✅ Complete

## Purpose

When LSP diagnostics change, this sends the list of changed file URIs to the Claude CLI as a `diagnostics_changed` notification. This enables Claude to detect errors/warnings in real time and automatically suggest fixes.

## Dependencies

- [x] Phase 0: Foundation Infrastructure (complete)
  - WebSocket transport capability (`ws_send`)

## Input

Automatically triggered when Neovim's `DiagnosticChanged` autocmd event fires.

## Output

JSON-RPC notification sent via WebSocket:

```json
{
  "jsonrpc": "2.0",
  "method": "diagnostics_changed",
  "params": {
    "uris": ["file:///path/to/file1.lua", "file:///path/to/file2.lua"]
  }
}
```

### Field Details

| Field | Type | Description |
|-------|------|-------------|
| `uris` | string[] | Array of `file://` URIs for files whose diagnostics changed |

## Implementation Plan

### File Location

`lua/claude-code/notifications.lua`

### Implementation Steps

1. **Register autocmd**: Create `DiagnosticChanged` autocmd
2. **Collect URIs**: Extract URIs of changed buffers from the event
   - Generate URI with `vim.uri_from_bufnr(args.buf)`
3. **Send notification**: Send `diagnostics_changed` message via WebSocket
4. **Configuration integration**: Control sending via the `diagnostics.enabled` setting

### Pseudocode

```lua
local function setup_diagnostics_notification(ws_send, config)
  if not config.diagnostics.enabled then
    return
  end

  vim.api.nvim_create_autocmd("DiagnosticChanged", {
    group = vim.api.nvim_create_augroup("ClaudeCodeDiagnostics", { clear = true }),
    callback = function(args)
      -- Only process if buffer is valid and has a file
      if not args.buf or not vim.api.nvim_buf_is_valid(args.buf) then
        return
      end

      local buf_name = vim.api.nvim_buf_get_name(args.buf)
      if buf_name == "" then
        return
      end

      local uri = vim.uri_from_bufnr(args.buf)

      ws_send({
        jsonrpc = "2.0",
        method = "diagnostics_changed",
        params = {
          uris = { uri },
        },
      })
    end,
  })
end
```

### Considerations

- **Debounce**: Diagnostics can change frequently, so consider applying debounce (optional)
- **Multiple files**: A single event could change diagnostics for multiple files, but Neovim's `DiagnosticChanged` fires per buffer, so it typically contains a single URI
- **Connection state check**: Do not send when there is no WebSocket connection (ignore silently)
- **Configuration disabled**: Do not register the autocmd if `diagnostics.enabled = false`

## Acceptance Criteria

- [ ] A `diagnostics_changed` notification is sent when LSP diagnostics change
- [ ] The `uris` array contains correct `file://` URIs
- [ ] No notification is sent when `diagnostics.enabled = false`
- [ ] No notification is sent for buffers without a file name
- [ ] Silently ignored without error when there is no WebSocket connection
- [ ] The autocmd group is set up correctly to prevent duplicate registration

## Reference Specs

- [05-notifications.md section 5.3](../05-notifications.md) - diagnostics_changed notification (DGN-01~02)
- [07-plugin-api.md section 7.1](../07-plugin-api.md) - `diagnostics.enabled` setting

## Estimated Time: ~1 hour
