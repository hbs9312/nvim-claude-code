# Phase 1-10: getCurrentSelection Tool

## Status: ✅ Complete

## Purpose

Expose the current active buffer's selection or cursor position as an MCP tool. This enables Claude to query the user's current editor state to understand context.

## Dependencies

- [x] Phase 0: Foundation Infrastructure (complete)
- [ ] Phase 1-01: Tool Registration System (required, incomplete)
- [ ] Phase 1-09: selection-tracking (required, incomplete)

## Input

None (tool with no parameters).

## Output

```json
// Success (Visual selection or cursor position)
{
  "content": [{
    "type": "text",
    "text": "{\"success\": true, \"text\": \"selected content\", \"filePath\": \"/path/to/file\", \"selection\": {\"start\": {\"line\": 0, \"character\": 0}, \"end\": {\"line\": 0, \"character\": 10}}}"
  }]
}

// Failure (no active editor)
{
  "content": [{
    "type": "text",
    "text": "{\"success\": false, \"message\": \"No active editor found\"}"
  }]
}
```

> Note: line and character are **0-indexed**.

## Implementation Plan

### File: `lua/claude-code/tools/selection.lua` (extending existing)

1. **Tool registration**
   ```lua
   tools.register("getCurrentSelection", {
     description = "Get the current selection in the active editor",
     inputSchema = {
       type = "object",
       properties = {},
     },
     handler = function(args)
       return M.get_current()
     end,
   })
   ```

2. **get_current() implementation**
   ```lua
   function M.get_current()
     -- Collect real-time info (current state, not cache)
     local info = get_selection_info()

     if not info then
       return {
         content = {{
           type = "text",
           text = vim.json.encode({
             success = false,
             message = "No active editor found",
           }),
         }},
       }
     end

     return {
       content = {{
         type = "text",
         text = vim.json.encode({
           success = true,
           text = info.text,
           filePath = info.filePath,
           selection = info.selection,
         }),
       }},
     }
   end
   ```

3. **Active editor detection**
   - Check whether `vim.api.nvim_get_current_buf()` has a valid file path
   - Scratch buffers, special buffers (help, terminal, etc.) are treated as "No active editor"

## Acceptance Criteria

- [ ] Calling during Visual mode selection → returns text + range (0-indexed)
- [ ] Calling at Normal mode cursor position → returns isEmpty=true with cursor position
- [ ] No active editor (scratch buffer) → returns `{success: false}`
- [ ] filePath is an absolute path
- [ ] line/character are 0-indexed

## Reference Specs

- [04-tools.md](../04-tools.md) Section 4.4 — getCurrentSelection

## Estimated Time: ~1 hour
