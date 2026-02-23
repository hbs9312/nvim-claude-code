# Phase 1-11: getLatestSelection Tool

## Status: ✅ Complete

## Purpose

Return the most recent selection from the cache. It has the same format as `getCurrentSelection`, but instead of returning the current state, it returns the last meaningful selection (Visual selection) from the cache. Claude uses this to understand the user's recent area of interest.

## Dependencies

- [x] Phase 0: Foundation Infrastructure (complete)
- [ ] Phase 1-01: Tool Registration System (required, incomplete)
- [ ] Phase 1-09: selection-tracking (required, incomplete)

## Input

None (tool with no parameters).

## Output

Same format as `getCurrentSelection`:

```json
// Previous selection exists
{
  "content": [{
    "type": "text",
    "text": "{\"success\": true, \"text\": \"previously selected\", \"filePath\": \"/path/to/file\", \"selection\": {\"start\": {\"line\": 5, \"character\": 0}, \"end\": {\"line\": 10, \"character\": 15}}}"
  }]
}

// No previous selection
{
  "content": [{
    "type": "text",
    "text": "{\"success\": false, \"message\": \"No selection history\"}"
  }]
}
```

## Implementation Plan

### File: `lua/claude-code/tools/selection.lua` (extending existing)

1. **Tool registration**
   ```lua
   tools.register("getLatestSelection", {
     description = "Get the most recent selection from the editor",
     inputSchema = {
       type = "object",
       properties = {},
     },
     handler = function(args)
       return M.get_latest()
     end,
   })
   ```

2. **get_latest() implementation**
   ```lua
   function M.get_latest()
     local info = M._latest

     if not info then
       return {
         content = {{
           type = "text",
           text = vim.json.encode({
             success = false,
             message = "No selection history",
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

3. **Cache behavior**
   - `M._latest` is updated in Phase 1-09's ModeChanged handler on Visual → Normal transition
   - If no Visual selection has ever been made, it is nil → `{success: false}`

## Acceptance Criteria

- [ ] After a Visual selection followed by returning to Normal mode → getLatestSelection returns the previous selection
- [ ] Multiple selections → only the most recent selection is returned
- [ ] No selection has ever been made → `{success: false, message: "No selection history"}`
- [ ] Same output format as getCurrentSelection (success, text, filePath, selection)

## Reference Specs

- [04-tools.md](../04-tools.md) Section 4.5 — getLatestSelection

## Estimated Time: ~0.5 hours
