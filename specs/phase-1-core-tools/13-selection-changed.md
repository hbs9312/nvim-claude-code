# Phase 1-13: selection_changed Notification (300ms Debounce)

## Status: ✅ Complete

## Purpose

Send a `selection_changed` notification to the Claude CLI when the editor selection changes. A 300ms debounce is applied to prevent unnecessary messages from frequent cursor movements, and the notification is not sent if the selection is the same as the previous one.

## Dependencies

- [x] Phase 0: Foundation Infrastructure (complete)
- [ ] Phase 1-01: Tool Registration System (required, incomplete)
- [ ] Phase 1-09: selection-tracking (required, incomplete)

## Input

Selection change events (triggered by Phase 1-09 autocmds, cache update)

## Output

JSON-RPC notification sent via WebSocket:

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

## Implementation Plan

### File: `lua/claude-code/tools/selection.lua` (extending existing)

1. **Debounce timer**
   ```lua
   local timer = vim.uv.new_timer()
   local DEBOUNCE_MS = 300
   local last_sent = nil  -- Last sent selection info
   ```

2. **Selection comparison function**
   ```lua
   local function selection_equal(a, b)
     if a == nil or b == nil then return a == b end
     return a.filePath == b.filePath
       and a.selection.start.line == b.selection.start.line
       and a.selection.start.character == b.selection.start.character
       and a.selection["end"].line == b.selection["end"].line
       and a.selection["end"].character == b.selection["end"].character
   end
   ```

3. **Debounced send**
   ```lua
   local function schedule_send()
     timer:stop()
     timer:start(DEBOUNCE_MS, 0, vim.schedule_wrap(function()
       local current = M._current
       if current and not selection_equal(current, last_sent) then
         last_sent = vim.deepcopy(current)
         -- Send notification via WebSocket
         ws.send_notification("selection_changed", {
           text = current.text,
           filePath = current.filePath,
           fileUrl = current.fileUrl,
           selection = current.selection,
         })
       end
     end))
   end
   ```

4. **Autocmd integration (extending Phase 1-09)**
   ```lua
   -- Add to Phase 1-09's autocmd callback
   vim.api.nvim_create_autocmd({"CursorMoved", "CursorMovedI", "ModeChanged"}, {
     group = augroup,
     callback = function()
       M._current = get_selection_info()
       schedule_send()  -- Schedule debounced notification send
     end,
   })
   ```

5. **Cleanup**
   ```lua
   function M.stop()
     if timer then
       timer:stop()
       timer:close()
     end
   end
   ```

## Acceptance Criteria

- [ ] Notification is sent 300ms after selection change (SEL-01, SEL-02)
- [ ] Consecutive changes within 300ms result in only the last change being sent (debounce)
- [ ] Notification is not sent if the selection is the same as the previous one (SEL-03)
- [ ] line/character are 0-indexed (SEL-04)
- [ ] isEmpty is accurate (Visual=false, Normal=true)
- [ ] filePath and fileUrl are included
- [ ] No errors when WebSocket is not connected (silently ignored)

## Reference Specs

- [05-notifications.md](../05-notifications.md) Section 5.1 — selection_changed
- SEL-01: Send via WebSocket on editor selection change
- SEL-02: 300ms debounce
- SEL-03: Do not send if selection is the same as previous
- SEL-04: line/character are 0-indexed

## Estimated Time: ~1 hour
