# Phase 1-03: openFile — startText/endText Range Selection

## Status: ✅ Complete

## Purpose

Add text-pattern-based range finding and selection to `openFile` using `startText`/`endText`. When Claude wants to show a specific function or code block to the user, this automatically selects the relevant region for visual highlighting.

## Dependencies

- [x] Phase 0: Foundation Infrastructure (complete)
- [ ] Phase 1-01: Tool Registration System (required, incomplete)
- [ ] Phase 1-02: openFile Basic (required, incomplete)

## Input

Additional parameters on top of the existing openFile parameters:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `startText` | string | N | Text pattern for selection start |
| `endText` | string | N | Text pattern for selection end |
| `selectToEndOfLine` | boolean | N | Extend selection to end of line |

```json
{
  "filePath": "/path/to/file.lua",
  "startText": "function hello",
  "endText": "end",
  "selectToEndOfLine": false
}
```

## Output

Same as the existing openFile response. The file is opened and the cursor moves to the matching range or it is selected in Visual mode.

## Implementation Plan

### File: `lua/claude-code/tools/open_file.lua` (extending existing)

1. **Text pattern search function**
   ```lua
   local function find_text(bufnr, text, start_from)
     -- Return the first line number containing text in the buffer
     -- start_from: line to start searching from (optional, used for endText search)
     local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
     for i = (start_from or 1), #lines do
       if lines[i]:find(text, 1, true) then  -- plain text search
         return i
       end
     end
     return nil
   end
   ```

2. **Range selection logic**
   - `startText` only: move cursor to that line
   - `startText` + `endText`: Visual select from start line to end line
   - `selectToEndOfLine=true`: extend selection to end of line
   - Pattern not found: just open the file and show a warning (not an error)

3. **Cursor movement / Visual selection**
   ```lua
   -- Move cursor
   vim.api.nvim_win_set_cursor(0, {start_line, 0})

   -- Visual selection (startText + endText)
   vim.cmd("normal! " .. start_line .. "GV" .. end_line .. "G")
   ```

4. **Screen scrolling**
   - Apply `zz` or `zt` so the selected range is visible on screen

## Acceptance Criteria

- [ ] Cursor moves to the correct line matching the startText pattern
- [ ] startText + endText results in a Visual selection of the range
- [ ] selectToEndOfLine=true extends selection to end of line
- [ ] Pattern not found: file opens without error (warning only)
- [ ] Selected range is displayed at the center of the screen

## Reference Specs

- [04-tools.md](../04-tools.md) Section 4.3 — openFile details

## Estimated Time: ~1 hour
