# Phase 2-06: close_tab Tool

## Status: ✅ Complete

## Purpose

An MCP tool that closes a tab/buffer specified by name. Registered in `tools/list` without a description, making it effectively hidden (Claude will not use it proactively), but it can be called internally by the CLI.

## Dependencies

- [x] Phase 0: Foundation Infrastructure (complete)
- [ ] Phase 1: Core Tools (required, incomplete)
  - Needs to be registered in Phase 1-01 tool-registry (`tools/init.lua`)

## Input

```json
{ "tab_name": "filename.lua" }
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `tab_name` | string | Y | Name of the buffer to close (file name or tab title) |

## Output

```json
{ "content": [{ "type": "text", "text": "TAB_CLOSED" }] }
```

Always returns the string `"TAB_CLOSED"` (including for non-existent buffers).

## Implementation Plan

### File Location

`lua/claude-code/tools/documents.lua` (same file as checkDocumentDirty, saveDocument)

### Implementation Steps

1. **Tool registration**: Register `close_tab` in the tool-registry
   - Registered **without a description** (hidden tool)
   - Included in `tools/list` response but with an empty description field
2. **Find buffer**: Search for a buffer by `tab_name`
   - Attempt exact name matching with `vim.fn.bufnr(tab_name)`
   - Fall back to partial matching (matching the end of the file name)
3. **Delete buffer**: `vim.api.nvim_buf_delete(bufnr, { force = true })` (equivalent to bwipeout)
4. **Return result**: Always return `"TAB_CLOSED"`

### Pseudocode

```lua
local function close_tab(params)
  local tab_name = params.tab_name
  local bufnr = vim.fn.bufnr(tab_name)

  if bufnr ~= -1 and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end

  return "TAB_CLOSED"
end
```

### Special Registration Notes

```lua
-- Register in tool-registry with an empty description
registry.register({
  name = "close_tab",
  description = "",  -- Hidden: no description
  inputSchema = {
    type = "object",
    properties = {
      tab_name = { type = "string" },
    },
    required = { "tab_name" },
  },
  handler = close_tab,
})
```

### Notes

- Returns `"TAB_CLOSED"` without error even for non-existent buffers (matches VS Code behavior)
- `force = true` forces close even if there are unsaved changes
- Diff-related buffers can also be closed by name

## Acceptance Criteria

- [ ] The buffer specified by name is closed (wiped out)
- [ ] Returns `"TAB_CLOSED"` without error for non-existent buffers
- [ ] Buffers with unsaved changes are forcefully closed
- [ ] `close_tab` is included in the `tools/list` response with an empty description
- [ ] After closing, the buffer is removed from the buffer list

## Reference Specs

- [04-tools.md section 4.12](../04-tools.md) - close_tab tool spec
- [07-plugin-api.md section 7.6](../07-plugin-api.md) - Module structure (`tools/documents.lua`)

## Estimated Time: ~0.5 hours
