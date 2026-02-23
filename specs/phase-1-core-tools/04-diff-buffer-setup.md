# Phase 1-04: Create Scratch Buffers for Diff (old/new)

## Status: ✅ Complete

## Purpose

Create two scratch buffers (original/proposed) for the `openDiff` tool. As the data layer for the diff view, the original file contents and Claude's proposed changes are each loaded into separate temporary buffers.

## Dependencies

- [x] Phase 0: Foundation Infrastructure (complete)
- [ ] Phase 1-01: Tool Registration System (required, incomplete)

## Input

```json
{
  "old_file_path": "/path/to/original.lua",
  "new_file_path": "/path/to/modified.lua",
  "new_file_contents": "-- Modified content\nlocal M = {}\n...",
  "tab_name": "Proposed changes"
}
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `old_file_path` | string | Y | Original file path |
| `new_file_path` | string | Y | Target file path for modifications |
| `new_file_contents` | string | Y | Full contents of the modified file |
| `tab_name` | string | N | Display name for the diff window |

## Output

Two scratch buffers:
- **old buffer**: original file contents (read from disk)
- **new buffer**: proposed contents (new_file_contents)

Attributes of each buffer:
- `buftype = "nofile"` (not associated with a file)
- `bufhidden = "wipe"` (automatically deleted when window is closed)
- `swapfile = false`
- filetype is inferred from the original file extension
- new buffer: `readonly = true`, `modifiable = false`

## Implementation Plan

### File: `lua/claude-code/diff.lua`

1. **Diff session struct**
   ```lua
   -- Diff session state management
   local DiffSession = {
     old_buf = nil,       -- Original buffer ID
     new_buf = nil,       -- Proposed buffer ID
     old_file_path = "",  -- Original file path
     new_file_path = "",  -- Target file path
     new_file_contents = "", -- Full proposed contents
     tab_name = "",       -- Display name
     callback = nil,      -- Response callback
   }
   ```

2. **Create original buffer (create_old_buffer)**
   ```lua
   local old_buf = vim.api.nvim_create_buf(false, true)  -- nofile, scratch
   -- Read original file from disk
   local lines = vim.fn.readfile(old_file_path)
   vim.api.nvim_buf_set_lines(old_buf, 0, -1, false, lines)
   -- Set buffer attributes
   vim.bo[old_buf].buftype = "nofile"
   vim.bo[old_buf].bufhidden = "wipe"
   vim.bo[old_buf].swapfile = false
   -- Set filetype (based on extension)
   local ft = vim.filetype.match({ filename = old_file_path })
   if ft then vim.bo[old_buf].filetype = ft end
   -- Set name (for winbar/statusline)
   vim.api.nvim_buf_set_name(old_buf, "Original: " .. vim.fn.fnamemodify(old_file_path, ":t"))
   ```

3. **Create proposed buffer (create_new_buffer)**
   ```lua
   local new_buf = vim.api.nvim_create_buf(false, true)
   local lines = vim.split(new_file_contents, "\n", { plain = true })
   vim.api.nvim_buf_set_lines(new_buf, 0, -1, false, lines)
   -- Set buffer attributes
   vim.bo[new_buf].buftype = "nofile"
   vim.bo[new_buf].bufhidden = "wipe"
   vim.bo[new_buf].swapfile = false
   -- Set filetype
   local ft = vim.filetype.match({ filename = new_file_path })
   if ft then vim.bo[new_buf].filetype = ft end
   -- readonly + nomodifiable
   vim.bo[new_buf].readonly = true
   vim.bo[new_buf].modifiable = false
   -- Set name
   vim.api.nvim_buf_set_name(new_buf, "Proposed: " .. vim.fn.fnamemodify(new_file_path, ":t"))
   ```

4. **Tool registration**
   - name: `"openDiff"`
   - handler: **blocking** (callback pattern)
   - After buffer creation, proceed to the next step (layout)

## Acceptance Criteria

- [ ] old buffer correctly contains the original file contents from disk
- [ ] new buffer correctly contains new_file_contents
- [ ] Both buffers have `buftype=nofile`, `swapfile=false`
- [ ] new buffer has `readonly=true`, `modifiable=false`
- [ ] filetype is set according to the file extension (.lua → lua, .py → python)
- [ ] If the original file does not exist, an empty old buffer is created (detailed handling in Phase 1-08)

## Reference Specs

- [06-diff-ui.md](../06-diff-ui.md) Section 6.3 (steps 2, 3) — Buffer preparation
- [04-tools.md](../04-tools.md) Section 4.2 — openDiff input/output

## Estimated Time: ~2 hours
