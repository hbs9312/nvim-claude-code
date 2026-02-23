# Phase 2-02: getWorkspaceFolders Tool

## Status: ✅ Complete

## Purpose

An MCP tool that returns workspace folder information. Used by Claude to accurately resolve file paths by identifying the project root path.

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
    "text": "{\"success\": true, \"folders\": [{\"name\": \"project\", \"uri\": \"file:///path/to/workspace\", \"path\": \"/path/to/workspace\"}], \"rootPath\": \"/path/to/workspace\"}"
  }]
}
```

### Output Field Details

| Field | Type | Description |
|-------|------|-------------|
| `success` | boolean | Always `true` |
| `folders[].name` | string | Folder name (directory name) |
| `folders[].uri` | string | Path in `file://` URI format |
| `folders[].path` | string | Absolute path |
| `rootPath` | string | Root workspace path |

## Implementation Plan

### File Location

`lua/claude-code/tools/editors.lua` (same file as getOpenEditors)

### Implementation Steps

1. **Tool registration**: Register `getWorkspaceFolders` in the tool-registry (MCP internal tool)
2. **Get current directory**: Based on `vim.fn.getcwd()`
3. **Check LSP workspace** (optional): Use `vim.lsp.buf.list_workspace_folders()` if available
4. **Construct folder information**:
   - `name`: `vim.fn.fnamemodify(cwd, ":t")` (directory name)
   - `uri`: `"file://" .. cwd`
   - `path`: `cwd` (absolute path)
5. **Set rootPath**: Path of the first folder
6. **Response format**: JSON-encode and return in MCP content format

### Pseudocode

```lua
local function get_workspace_folders()
  local cwd = vim.fn.getcwd()
  local name = vim.fn.fnamemodify(cwd, ":t")

  return {
    success = true,
    folders = {
      {
        name = name,
        uri = "file://" .. cwd,
        path = cwd,
      },
    },
    rootPath = cwd,
  }
end
```

## Acceptance Criteria

- [ ] The current working directory is returned accurately
- [ ] `uri` is correctly formatted with the `file://` prefix
- [ ] `name` contains only the directory name (not the full path)
- [ ] `path` is an absolute path
- [ ] `rootPath` matches `folders[0].path`
- [ ] `success` is returned as `true`
- [ ] `getWorkspaceFolders` is registered in the `tools/list` response

## Reference Specs

- [04-tools.md section 4.8](../04-tools.md) - getWorkspaceFolders tool spec
- [07-plugin-api.md section 7.6](../07-plugin-api.md) - Module structure (`tools/editors.lua`)

## Estimated Time: ~0.5 hours
