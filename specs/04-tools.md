# 04. MCP Tools Detailed Spec

## 4.1 Tool List and Priority

| # | Tool Name | Priority | Blocking | MCP Exposure | Description |
|---|-----------|----------|----------|--------------|-------------|
| 1 | `openDiff` | **P0** | **Yes** | Internal | Display diff view, wait for accept/reject |
| 2 | `openFile` | **P0** | No | Internal | Open file + range selection |
| 3 | `getCurrentSelection` | **P0** | No | Internal | Query current selection |
| 4 | `getLatestSelection` | **P0** | No | Internal | Query most recent selection |
| 5 | `getDiagnostics` | **P0** | No | **Public** | Provide LSP diagnostic information |
| 6 | `getOpenEditors` | **P1** | No | Internal | List of open buffers |
| 7 | `getWorkspaceFolders` | **P1** | No | Internal | Workspace folders |
| 8 | `checkDocumentDirty` | **P1** | No | Internal | Check for unsaved changes |
| 9 | `saveDocument` | **P1** | No | Internal | Save file |
| 10 | `closeAllDiffTabs` | **P1** | No | Internal | Close all diff windows |
| 11 | `close_tab` | **P2** | No | Not exposed | Close buffer/tab |
| 12 | `executeCode` | **P2** | No | **Public** | Execute code (optional implementation) |

> **P0**: Core functionality, required for initial release
> **P1**: Important functionality, targeted for initial release
> **P2**: Supplementary functionality, for subsequent releases

---

## 4.2 openDiff

**The most critical tool.** Called when Claude proposes file modifications.

### Behavior

1. Display the original file and modified content in a side-by-side split diff
2. **Blocking** (response held) until the user accepts or rejects
3. Accept → save modified content to file, respond with `FILE_SAVED`
4. Reject → keep original, respond with `DIFF_REJECTED`
5. If the diff window is closed → treat as reject

### Input

```json
{
  "old_file_path": "/path/to/original.lua",
  "new_file_path": "/path/to/modified.lua",
  "new_file_contents": "-- Modified content...",
  "tab_name": "Proposed changes"
}
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `old_file_path` | string | Y | Original file path |
| `new_file_path` | string | Y | Target file path for modifications |
| `new_file_contents` | string | Y | Full contents of the modified file |
| `tab_name` | string | N | Display name for the diff window |

### Output

```json
// Accept
{ "content": [{ "type": "text", "text": "FILE_SAVED" }] }

// Reject
{ "content": [{ "type": "text", "text": "DIFF_REJECTED" }] }
```

### Neovim Implementation Design

```
openDiff call received
  → Read original file contents
  → Create 2 scratch buffers (old, new)
  → Arrange side by side with vsplit
  → Apply diffthis
  → Set accept/reject keymaps:
      <CR> or :accept → write new_file_contents to file → respond "FILE_SAVED"
      q or :reject    → keep original → respond "DIFF_REJECTED"
      BufWinLeave     → treat as reject
  → Hold response (await callback)
```

### Multi-File Behavior

When Claude modifies multiple files:
- The CLI calls `openDiff` **sequentially** (one at a time)
- Each call occurs only after receiving the response from the previous one
- This naturally results in a "show one at a time in the same window" UX

```
CLI → openDiff(file1) → [Neovim: show diff, wait]
                         User accepts →
CLI ← FILE_SAVED
CLI → openDiff(file2) → [Neovim: show diff, wait]
                         User accepts →
CLI ← FILE_SAVED
CLI → openDiff(file3) → ...
```

---

## 4.3 openFile

### Behavior

Open the specified file and optionally select a range based on text patterns.

### Input

```json
{
  "filePath": "/path/to/file.lua",
  "preview": false,
  "startText": "function hello",
  "endText": "}",
  "selectToEndOfLine": false,
  "makeFrontmost": true
}
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `filePath` | string | Y | File path |
| `preview` | boolean | N | Preview mode (Neovim: unused, can be ignored) |
| `startText` | string | N | Text pattern for selection start |
| `endText` | string | N | Text pattern for selection end |
| `selectToEndOfLine` | boolean | N | Select to end of line |
| `makeFrontmost` | boolean | N | Whether to switch focus |

### Output

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

### Neovim Implementation

```lua
-- Open file
vim.cmd("edit " .. filePath)

-- Find range by startText/endText
if startText then
  local start_line = find_text(startText)
  local end_line = endText and find_text(endText, start_line) or start_line
  -- Visual selection or cursor movement
end
```

---

## 4.4 getCurrentSelection

### Behavior

Return the selection (Visual mode) or cursor position of the currently active buffer.

### Input

None.

### Output

```json
// Success
{
  "content": [{
    "type": "text",
    "text": "{\"success\": true, \"text\": \"selected content\", \"filePath\": \"/path/to/file\", \"selection\": {\"start\": {\"line\": 0, \"character\": 0}, \"end\": {\"line\": 0, \"character\": 10}}}"
  }]
}

// Failure
{
  "content": [{
    "type": "text",
    "text": "{\"success\": false, \"message\": \"No active editor found\"}"
  }]
}
```

> Note: `line` and `character` are **0-indexed**.

---

## 4.5 getLatestSelection

Same format as `getCurrentSelection`. Returns the most recently selected region from cache.

### Neovim Implementation

Store the last selection state in cache using autocmds such as `CursorMoved` and `ModeChanged`.

---

## 4.6 getDiagnostics

### Behavior

Return Neovim LSP diagnostic information. **MCP public tool** (`mcp__ide__getDiagnostics`).

### Input

```json
{ "uri": "file:///path/to/file.lua" }
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `uri` | string | **N** (optional) | File URI. If omitted, returns diagnostics for all files |

### Output

```json
{
  "content": [{
    "type": "text",
    "text": "[{\"uri\": \"file:///path/to/file\", \"diagnostics\": [{\"message\": \"Error msg\", \"severity\": \"Error\", \"range\": {\"start\": {\"line\": 0, \"character\": 0}}, \"source\": \"lua_ls\"}]}]"
  }]
}
```

### Neovim Implementation

```lua
local diagnostics = vim.diagnostic.get(bufnr)
-- severity mapping: 1=Error, 2=Warning, 3=Information, 4=Hint
```

---

## 4.7 getOpenEditors

### Behavior

Return the list of open buffers.

### Output

```json
{
  "content": [{
    "type": "text",
    "text": "{\"tabs\": [{\"uri\": \"file:///path/to/file\", \"isActive\": true, \"label\": \"file.lua\", \"languageId\": \"lua\", \"isDirty\": false}]}"
  }]
}
```

### Neovim Implementation

```lua
-- Iterate over listed buffers with vim.api.nvim_list_bufs()
-- filetype → languageId mapping
-- vim.bo[bufnr].modified → isDirty
```

---

## 4.8 getWorkspaceFolders

### Output

```json
{
  "content": [{
    "type": "text",
    "text": "{\"success\": true, \"folders\": [{\"name\": \"project\", \"uri\": \"file:///path/to/workspace\", \"path\": \"/path/to/workspace\"}], \"rootPath\": \"/path/to/workspace\"}"
  }]
}
```

### Neovim Implementation

```lua
-- vim.fn.getcwd() or vim.lsp.buf.list_workspace_folders()
```

---

## 4.9 checkDocumentDirty

### Input

```json
{ "filePath": "/path/to/file.lua" }
```

### Output

```json
// Open and modified
{
  "content": [{
    "type": "text",
    "text": "{\"success\": true, \"filePath\": \"/path/to/file.lua\", \"isDirty\": true, \"isUntitled\": false}"
  }]
}

// Not open
{
  "content": [{
    "type": "text",
    "text": "{\"success\": false, \"message\": \"Document not open: /path/to/file.lua\"}"
  }]
}
```

---

## 4.10 saveDocument

### Input

```json
{ "filePath": "/path/to/file.lua" }
```

### Output

```json
{
  "content": [{
    "type": "text",
    "text": "{\"success\": true, \"filePath\": \"/path/to/file.lua\", \"saved\": true, \"message\": \"Document saved successfully\"}"
  }]
}
```

---

## 4.11 closeAllDiffTabs

### Behavior

Close all currently open diff windows.

### Input

None.

### Output

```json
{ "content": [{ "type": "text", "text": "closed N diff tabs" }] }
```

---

## 4.12 close_tab

### Behavior

Close a tab/buffer by name. Registered in `tools/list` without a description (effectively not exposed).

### Input

```json
{ "tab_name": "filename.lua" }
```

### Output

```json
{ "content": [{ "type": "text", "text": "TAB_CLOSED" }] }
```

---

## 4.13 executeCode (Optional)

### Behavior

Execute code. In VS Code this runs in a Jupyter kernel, but alternative implementations are possible in Neovim.

### Input

```json
{ "code": "print('Hello')" }
```

### Implementation Options

- **Not implemented**: Do not register the tool (simplest approach)
- **Terminal execution**: Run code in Neovim terminal and capture output
- **External process**: Execute with `vim.system()`
