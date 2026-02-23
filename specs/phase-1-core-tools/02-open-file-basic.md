# Phase 1-02: openFile — Open File by Path

## Status: ✅ Complete

## Purpose

Open a file specified by `filePath` in Neovim. This is the basic tool used when Claude shows a specific file to the user or retrieves file information.

## Dependencies

- [x] Phase 0: Foundation Infrastructure (complete)
- [ ] Phase 1-01: Tool Registration System (required, incomplete)

## Input

```json
{
  "filePath": "/absolute/path/to/file.lua",
  "preview": false,
  "makeFrontmost": true
}
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `filePath` | string | Y | Absolute file path |
| `preview` | boolean | N | Preview mode (ignored in Neovim) |
| `makeFrontmost` | boolean | N | Whether to switch focus (default: true) |

## Output

```json
// makeFrontmost=true (or default)
{ "content": [{ "type": "text", "text": "Opened file: /path/to/file.lua" }] }

// makeFrontmost=false
{
  "content": [{
    "type": "text",
    "text": "{\"success\": true, \"filePath\": \"/path/to/file.lua\", \"languageId\": \"lua\", \"lineCount\": 42}"
  }]
}
```

## Implementation Plan

### File: `lua/claude-code/tools/open_file.lua`

1. **Tool registration**
   - name: `"openFile"`
   - inputSchema: filePath (required), preview, startText, endText, selectToEndOfLine, makeFrontmost
   - handler: non-blocking

2. **Open file**
   ```lua
   vim.cmd("edit " .. vim.fn.fnameescape(filePath))
   ```

3. **Response branching**
   - `makeFrontmost == true` (default): text response `"Opened file: <filePath>"`
   - `makeFrontmost == false`: JSON response `{success, filePath, languageId, lineCount}`
     - `languageId`: `vim.bo.filetype`
     - `lineCount`: `vim.api.nvim_buf_line_count(0)`

4. **Error handling**
   - Missing filePath → error response
   - File does not exist → Neovim opens a new buffer (default vim behavior) or error
   - Path is a directory → error response

## Acceptance Criteria

- [ ] Existing file path → file opens as the current buffer
- [ ] makeFrontmost=true → `"Opened file: ..."` text response
- [ ] makeFrontmost=false → JSON response (success, filePath, languageId, lineCount)
- [ ] Missing filePath → error response
- [ ] languageId is set correctly (e.g., .lua → "lua", .py → "python")

## Reference Specs

- [04-tools.md](../04-tools.md) Section 4.3 — openFile details

## Estimated Time: ~1 hour
