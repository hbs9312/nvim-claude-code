# Phase 2-04: saveDocument Tool

## Status: ✅ Complete

## Purpose

An MCP tool that saves a specified file. Used by Claude to automatically save after modifying a file or when an explicit save is requested.

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
| `filePath` | string | Y | Absolute path of the file to save |

## Output

### Success

```json
{
  "content": [{
    "type": "text",
    "text": "{\"success\": true, \"filePath\": \"/path/to/file.lua\", \"saved\": true, \"message\": \"Document saved successfully\"}"
  }]
}
```

### Failure (file is not open)

```json
{
  "content": [{
    "type": "text",
    "text": "{\"success\": false, \"filePath\": \"/path/to/file.lua\", \"saved\": false, \"message\": \"Document not open: /path/to/file.lua\"}"
  }]
}
```

### Failure (cannot save, e.g. readonly)

```json
{
  "content": [{
    "type": "text",
    "text": "{\"success\": false, \"filePath\": \"/path/to/file.lua\", \"saved\": false, \"message\": \"Failed to save: E45: 'readonly' option is set\"}"
  }]
}
```

### Output Field Details

| Field | Type | Description |
|-------|------|-------------|
| `success` | boolean | Whether the save succeeded |
| `filePath` | string | The saved file path |
| `saved` | boolean | Whether a save was actually performed |
| `message` | string | Result message |

## Implementation Plan

### File Location

`lua/claude-code/tools/documents.lua` (same file as checkDocumentDirty)

### Implementation Steps

1. **Tool registration**: Register `saveDocument` in the tool-registry (MCP internal tool)
2. **Find buffer**: Search for an open buffer by `filePath`
   - Return failure response if buffer does not exist or is not loaded
3. **Execute save**: `vim.api.nvim_buf_call(bufnr, function() vim.cmd("write") end)`
   - Wrap with `pcall` for error handling (readonly, permission issues, etc.)
4. **Return result**: Response based on success/failure

### Pseudocode

```lua
local function save_document(params)
  local file_path = params.filePath
  local bufnr = vim.fn.bufnr(file_path)

  if bufnr == -1 or not vim.api.nvim_buf_is_loaded(bufnr) then
    return {
      success = false,
      filePath = file_path,
      saved = false,
      message = "Document not open: " .. file_path,
    }
  end

  local ok, err = pcall(function()
    vim.api.nvim_buf_call(bufnr, function()
      vim.cmd("write")
    end)
  end)

  if ok then
    return {
      success = true,
      filePath = file_path,
      saved = true,
      message = "Document saved successfully",
    }
  else
    return {
      success = false,
      filePath = file_path,
      saved = false,
      message = "Failed to save: " .. tostring(err),
    }
  end
end
```

### Notes

- `vim.api.nvim_buf_call` executes the function in the context of the given buffer, so `:write` saves to the correct file
- Wrapped with `pcall` to safely handle errors such as readonly or permission issues
- Even if `vim.bo[bufnr].modified` is false (no changes), the save is still performed (matches VS Code behavior)

## Acceptance Criteria

- [ ] A modified file is saved successfully (reflected on the file system)
- [ ] Returns `saved = true`, `success = true` after saving
- [ ] Returns `success = false` with error message for a file that is not open
- [ ] Returns `success = false` with error message for a readonly file
- [ ] After saving, the buffer's `modified` state changes to `false`
- [ ] `saveDocument` is registered in the `tools/list` response

## Reference Specs

- [04-tools.md section 4.10](../04-tools.md) - saveDocument tool spec
- [07-plugin-api.md section 7.6](../07-plugin-api.md) - Module structure (`tools/documents.lua`)

## Estimated Time: ~0.5 hours
