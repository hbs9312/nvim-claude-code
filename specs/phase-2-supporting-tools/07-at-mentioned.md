# Phase 2-07: at_mentioned Notification + :ClaudeAtMention Command

## Status: ✅ Complete

## Purpose

When the user executes the `:ClaudeAtMention` command, it sends the current file path and optionally the Visual selection range to the Claude CLI as an `at_mentioned` notification. This enables Claude to receive context about a specific file or code range to work with.

## Dependencies

- [x] Phase 0: Foundation Infrastructure (complete)
  - WebSocket transport capability (`ws_send`)

## Input

The user executes the `:ClaudeAtMention` command.

- **Executed in Normal mode**: Sends only the current file path
- **Executed in Visual mode** (or with `'<, '>` range): Sends file path + selection range

## Output

JSON-RPC notification sent via WebSocket:

### With selection range

```json
{
  "jsonrpc": "2.0",
  "method": "at_mentioned",
  "params": {
    "filePath": "/path/to/file.lua",
    "lineStart": 0,
    "lineEnd": 5
  }
}
```

### Without selection range (file only)

```json
{
  "jsonrpc": "2.0",
  "method": "at_mentioned",
  "params": {
    "filePath": "/path/to/file.lua"
  }
}
```

### Field Details

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `filePath` | string | Y | Absolute file path |
| `lineStart` | number | N | Selection start line (**0-indexed**) |
| `lineEnd` | number | N | Selection end line (**0-indexed**) |

## Implementation Plan

### File Location

- Command registration: `lua/claude-code/init.lua` or `lua/claude-code/commands.lua`
- Notification sending: `lua/claude-code/notifications.lua`

### Implementation Steps

1. **Register command**: Create `:ClaudeAtMention` user command (`range = true` option)
2. **Get current file path**: `vim.api.nvim_buf_get_name(0)` (absolute path)
3. **Check selection range**:
   - If a Visual mode range exists, use `line1`, `line2`
   - Convert from Neovim 1-indexed to 0-indexed (`line - 1`)
   - Omit `lineStart`/`lineEnd` fields if no selection
4. **WebSocket send**: Send in notification format (no id)
5. **Lua API**: Provide `claude.at_mention(filepath?, startline?, endline?)` function

### Pseudocode

```lua
-- Command registration
vim.api.nvim_create_user_command("ClaudeAtMention", function(opts)
  local file_path = vim.api.nvim_buf_get_name(0)
  if file_path == "" then
    vim.notify("No file to mention", vim.log.levels.WARN)
    return
  end

  local params = { filePath = file_path }

  -- Add Visual selection range if present (convert to 0-indexed)
  if opts.range == 2 then
    params.lineStart = opts.line1 - 1
    params.lineEnd = opts.line2 - 1
  end

  ws_send({
    jsonrpc = "2.0",
    method = "at_mentioned",
    params = params,
  })

  vim.notify("Mentioned: " .. vim.fn.fnamemodify(file_path, ":t"), vim.log.levels.INFO)
end, { range = true })
```

### Lua API

```lua
-- Programmatic interface
function M.at_mention(filepath, startline, endline)
  filepath = filepath or vim.api.nvim_buf_get_name(0)
  local params = { filePath = filepath }
  if startline and endline then
    params.lineStart = startline  -- Assumed to be already 0-indexed
    params.lineEnd = endline
  end
  ws_send({ jsonrpc = "2.0", method = "at_mentioned", params = params })
end
```

## Acceptance Criteria

- [ ] When executed in Normal mode, a notification containing only `filePath` is sent
- [ ] When executed after Visual mode selection, includes `filePath`, `lineStart`, `lineEnd`
- [ ] `lineStart`/`lineEnd` are correctly converted to 0-indexed
- [ ] When there is no selection, `lineStart`/`lineEnd` fields are omitted (absent, not null)
- [ ] When executed in a buffer with no file (empty buffer), a warning is displayed
- [ ] When there is no WebSocket connection, execution handles the error gracefully
- [ ] The `claude.at_mention()` Lua API works correctly

## Reference Specs

- [05-notifications.md section 5.2](../05-notifications.md) - at_mentioned notification (ATM-01~03)
- [07-plugin-api.md section 7.2](../07-plugin-api.md) - :ClaudeAtMention command
- [07-plugin-api.md section 7.3](../07-plugin-api.md) - `claude.at_mention()` Lua API

## Estimated Time: ~1 hour
