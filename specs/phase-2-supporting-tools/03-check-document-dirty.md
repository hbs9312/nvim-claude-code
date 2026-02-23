# Phase 2-03: checkDocumentDirty Tool

## Status: ✅ Complete

## Purpose

An MCP tool that checks whether a specified file is open and has unsaved changes. Used by Claude to verify the current state before modifying a file or to determine whether to save.

## Dependencies

- [x] Phase 0: Foundation Infrastructure (complete)
- [ ] Phase 1: Core Tools (required, incomplete)
  - Needs to be registered in Phase 1-01 tool-registry (`tools/init.lua`)

## Input

```json
{ "filePath": "/path/to/file.lua" }
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `filePath` | string | Y | Absolute path of the file to check |

## Output

### Success (file is open)

```json
{
  "content": [{
    "type": "text",
    "text": "{\"success\": true, \"filePath\": \"/path/to/file.lua\", \"isDirty\": true, \"isUntitled\": false}"
  }]
}
```

### Failure (file is not open)

```json
{
  "content": [{
    "type": "text",
    "text": "{\"success\": false, \"message\": \"Document not open: /path/to/file.lua\"}"
  }]
}
```

### Output Field Details

| Field | Type | Description |
|-------|------|-------------|
| `success` | boolean | `true` if the file is open |
| `filePath` | string | The checked file path |
| `isDirty` | boolean | Whether unsaved changes exist |
| `isUntitled` | boolean | Whether this is an unnamed buffer (always `false`, since lookup is by file path in Neovim) |
| `message` | string | Error message on failure |

## Implementation Plan

### File Location

`lua/claude-code/tools/documents.lua`

### Implementation Steps

1. **Tool registration**: Register `checkDocumentDirty` in the tool-registry (MCP internal tool)
2. **Find buffer**: Search for an open buffer by `filePath`
   - Look up buffer number with `vim.fn.bufnr(filePath)`
   - Return failure response if buffer does not exist (`-1`) or is not loaded
3. **Check status**: Check dirty state with `vim.bo[bufnr].modified`
4. **Construct response**: Return appropriate JSON based on success/failure

### Pseudocode

```lua
local function check_document_dirty(params)
  local file_path = params.filePath
  local bufnr = vim.fn.bufnr(file_path)

  if bufnr == -1 or not vim.api.nvim_buf_is_loaded(bufnr) then
    return {
      success = false,
      message = "Document not open: " .. file_path,
    }
  end

  return {
    success = true,
    filePath = file_path,
    isDirty = vim.bo[bufnr].modified,
    isUntitled = false,
  }
end
```

## Acceptance Criteria

- [ ] Returns `isDirty = true` for an open, modified buffer
- [ ] Returns `isDirty = false` for an open, saved buffer
- [ ] Returns `success = false` with error message for a file that is not open
- [ ] `filePath` is returned matching the input value
- [ ] `isUntitled` is returned as `false`
- [ ] `checkDocumentDirty` is registered in the `tools/list` response

## Reference Specs

- [04-tools.md section 4.9](../04-tools.md) - checkDocumentDirty tool spec
- [07-plugin-api.md section 7.6](../07-plugin-api.md) - Module structure (`tools/documents.lua`)

## Estimated Time: ~0.5 hours
