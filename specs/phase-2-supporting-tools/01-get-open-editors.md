# Phase 2-01: getOpenEditors Tool

## Status: ✅ Complete

## Purpose

An MCP tool that returns the list of open buffers. Used by Claude to understand context by identifying the files currently being edited.

## Dependencies

- [x] Phase 0: Foundation Infrastructure (complete)
- [ ] Phase 1: Core Tools (required, incomplete)
  - Needs to be registered in Phase 1-01 tool-registry (`tools/init.lua`)

## Input

None. Called without parameters.

## Output

```json
{
  "content": [{
    "type": "text",
    "text": "{\"tabs\": [{\"uri\": \"file:///path/to/file.lua\", \"isActive\": true, \"label\": \"file.lua\", \"languageId\": \"lua\", \"isDirty\": false}]}"
  }]
}
```

### Output Field Details

| Field | Type | Description |
|-------|------|-------------|
| `tabs[].uri` | string | File path in `file://` URI format |
| `tabs[].isActive` | boolean | Whether this is the currently active buffer |
| `tabs[].label` | string | File name (excluding path) |
| `tabs[].languageId` | string | Language identifier (based on filetype) |
| `tabs[].isDirty` | boolean | Whether unsaved changes exist |

## Implementation Plan

### File Location

`lua/claude-code/tools/editors.lua`

### Implementation Steps

1. **Tool registration**: Register `getOpenEditors` in the tool-registry (with description, MCP internal tool)
2. **Buffer iteration**: Query all buffers with `vim.api.nvim_list_bufs()`
3. **Filtering**: Include only buffers with `buflisted` status (`vim.bo[bufnr].buflisted`)
4. **Information gathering**:
   - `uri`: `vim.uri_from_bufnr(bufnr)` or `"file://" .. vim.api.nvim_buf_get_name(bufnr)`
   - `isActive`: `vim.api.nvim_get_current_buf() == bufnr`
   - `label`: `vim.fn.fnamemodify(name, ":t")` (file name only)
   - `languageId`: `vim.bo[bufnr].filetype` → `"plaintext"` if empty string
   - `isDirty`: `vim.bo[bufnr].modified`
5. **Response format**: JSON-encode and return in MCP content format

### Pseudocode

```lua
local function get_open_editors()
  local current_buf = vim.api.nvim_get_current_buf()
  local tabs = {}

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[bufnr].buflisted then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name ~= "" then
        table.insert(tabs, {
          uri = vim.uri_from_bufnr(bufnr),
          isActive = (bufnr == current_buf),
          label = vim.fn.fnamemodify(name, ":t"),
          languageId = vim.bo[bufnr].filetype ~= "" and vim.bo[bufnr].filetype or "plaintext",
          isDirty = vim.bo[bufnr].modified,
        })
      end
    end
  end

  return { tabs = tabs }
end
```

## Acceptance Criteria

- [ ] Open buffer list is returned accurately
- [ ] The currently active buffer is marked with `isActive = true`
- [ ] Buffers with unsaved changes are marked with `isDirty = true`
- [ ] Unnamed buffers (empty name) are excluded from the list
- [ ] Non-`buflisted` buffers (help, terminal, etc.) are excluded
- [ ] `uri` is correctly formatted with the `file://` prefix
- [ ] `languageId` matches the filetype, and empty filetypes return `"plaintext"`
- [ ] `getOpenEditors` is registered in the `tools/list` response

## Reference Specs

- [04-tools.md section 4.7](../04-tools.md) - getOpenEditors tool spec
- [07-plugin-api.md section 7.6](../07-plugin-api.md) - Module structure (`tools/editors.lua`)

## Estimated Time: ~1 hour
