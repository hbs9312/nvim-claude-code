# 05. Notification (Neovim → Claude CLI)

Custom notifications outside the MCP protocol. Sent one-way from Neovim to Claude CLI (no response).

## 5.1 selection_changed

### Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| SEL-01 | Send via WebSocket when editor selection changes | Required |
| SEL-02 | Debounce **300ms** | Required |
| SEL-03 | Do not send if selection is the same as previous | Required |
| SEL-04 | line/character are **0-indexed** | Required |

### Message Structure

```json
{
  "jsonrpc": "2.0",
  "method": "selection_changed",
  "params": {
    "text": "selected text content",
    "filePath": "/absolute/path/to/file.lua",
    "fileUrl": "file:///absolute/path/to/file.lua",
    "selection": {
      "start": { "line": 10, "character": 5 },
      "end": { "line": 15, "character": 20 },
      "isEmpty": false
    }
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `text` | string | Selected text content (empty string `""` if none) |
| `filePath` | string | Absolute file path |
| `fileUrl` | string | `file://` URI |
| `selection.start.line` | number | Start line (0-indexed) |
| `selection.start.character` | number | Start column (0-indexed) |
| `selection.end.line` | number | End line (0-indexed) |
| `selection.end.character` | number | End column (0-indexed) |
| `selection.isEmpty` | boolean | Whether the selection is empty (cursor only, no selection) |

### Neovim Implementation

```lua
-- CursorMoved, CursorMovedI, ModeChanged autocmd
-- Visual mode: vim.fn.getpos("'<"), vim.fn.getpos("'>")
-- Normal mode: cursor position = start == end, isEmpty = true
-- Note: Neovim is 1-indexed → must convert to 0-indexed (line - 1)
```

### Debounce Implementation

```lua
local timer = vim.uv.new_timer()
local DEBOUNCE_MS = 300

local function on_selection_changed()
  timer:stop()
  timer:start(DEBOUNCE_MS, 0, vim.schedule_wrap(function()
    local selection = get_current_selection()
    if selection ~= last_selection then
      last_selection = selection
      ws_send(selection_changed_message(selection))
    end
  end))
end
```

---

## 5.2 at_mentioned

### Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| ATM-01 | Send when user executes @mention command | Recommended |
| ATM-02 | lineStart/lineEnd are **0-indexed** | Required |
| ATM-03 | Omit lineStart/lineEnd fields if there is no selection | Required |

### Message Structure

```json
// With selection
{
  "jsonrpc": "2.0",
  "method": "at_mentioned",
  "params": {
    "filePath": "/path/to/file.lua",
    "lineStart": 0,
    "lineEnd": 5
  }
}

// Without selection (file only)
{
  "jsonrpc": "2.0",
  "method": "at_mentioned",
  "params": {
    "filePath": "/path/to/file.lua"
  }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `filePath` | string | Y | Absolute file path |
| `lineStart` | number | N | Selection start line (0-indexed) |
| `lineEnd` | number | N | Selection end line (0-indexed) |

### Neovim Implementation

User command (e.g., `:ClaudeAtMention`) sends the current file/selection to Claude.

---

## 5.3 diagnostics_changed

### Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| DGN-01 | Send list of changed file URIs when LSP diagnostics change | Recommended |
| DGN-02 | Based on `vim.diagnostic` events | Recommended |

### Message Structure

```json
{
  "jsonrpc": "2.0",
  "method": "diagnostics_changed",
  "params": {
    "uris": ["file:///path/to/file1.lua", "file:///path/to/file2.lua"]
  }
}
```

### Neovim Implementation

```lua
-- DiagnosticChanged autocmd
vim.api.nvim_create_autocmd("DiagnosticChanged", {
  callback = function(args)
    local uri = vim.uri_from_bufnr(args.buf)
    ws_send(diagnostics_changed_message({ uris = { uri } }))
  end,
})
```

---

## 5.4 log_event (Optional)

### Message Structure

```json
{
  "jsonrpc": "2.0",
  "method": "log_event",
  "params": {
    "eventName": "run_claude_command",
    "eventData": {}
  }
}
```

Priority: **Optional**. For analytics/logging purposes. Can be omitted in the initial implementation.
