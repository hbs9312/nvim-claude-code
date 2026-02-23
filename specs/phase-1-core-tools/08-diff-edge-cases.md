# Phase 1-08: New File, Dirty Buffer, BufWinLeave

## Status: ✅ Complete

## Purpose

Safely handle diff edge cases. Ensure consistent behavior in abnormal situations such as creating a new file, a buffer that is already modified, or the user manually closing a window.

## Dependencies

- [x] Phase 0: Foundation Infrastructure (complete)
- [ ] Phase 1-01: Tool Registration System (required, incomplete)
- [ ] Phase 1-04: Create Scratch Buffers for Diff (required, incomplete)
- [ ] Phase 1-05: vsplit Layout (required, incomplete)
- [ ] Phase 1-06: Accept/Reject Keymaps (required, incomplete)
- [ ] Phase 1-07: Diff Cleanup (required, incomplete)

## Input

Various edge case scenarios:
1. Original file does not exist (new file creation)
2. Original file is already open and dirty (unsaved changes)
3. User manually closes the diff window (BufWinLeave)
4. new_file_contents is identical to the original
5. User attempts to edit the proposed buffer

## Output

Appropriate handling for each scenario and responses to the Claude CLI.

## Implementation Plan

### File: `lua/claude-code/diff.lua` (extending existing)

### 1. Original File Does Not Exist (New File)

```lua
local function create_old_buffer(old_file_path)
  local old_buf = vim.api.nvim_create_buf(false, true)

  if vim.fn.filereadable(old_file_path) == 1 then
    -- Existing file: read from disk
    local lines = vim.fn.readfile(old_file_path)
    vim.api.nvim_buf_set_lines(old_buf, 0, -1, false, lines)
  else
    -- New file: empty buffer (no content)
    -- An empty old buffer means the entire diff shows as "added"
  end

  return old_buf
end
```

### 2. Original File Is Open and Dirty

```lua
-- Always use disk contents for the old side (same behavior as VS Code)
-- vim.fn.readfile() reads directly from disk, unaffected by dirty buffer
-- Modifications in the dirty buffer are intentionally ignored
local lines = vim.fn.readfile(old_file_path)  -- Always disk-based
```

### 3. BufWinLeave → Reject Handling (Safety Guard)

```lua
local function setup_autocmds(session)
  session.augroup = vim.api.nvim_create_augroup("ClaudeDiff_" .. session.id, { clear = true })

  -- If a diff window is closed, treat it as reject
  for _, buf in ipairs({session.old_buf, session.new_buf}) do
    vim.api.nvim_create_autocmd("BufWinLeave", {
      group = session.augroup,
      buffer = buf,
      once = true,
      callback = function()
        if not session.resolved then
          -- Safety guard: window closed → reject
          vim.schedule(function()
            reject(session)
          end)
        end
      end,
    })
  end
end
```

### 4. Proposed Content Is Identical to Original

```lua
-- The diff is still shown, but it will be visually clear there are no changes
-- When diffthis is applied with no changes, there is no highlighting (natural Neovim behavior)
-- No additional handling needed — if the user accepts, the same content is simply saved
```

### 5. Prevent Editing of Proposed Buffer

```lua
-- Already set in Phase 1-04:
-- vim.bo[new_buf].readonly = true
-- vim.bo[new_buf].modifiable = false
-- If the user attempts to edit, Neovim automatically shows "Cannot make changes, 'modifiable' is off" error
```

### 6. Create Parent Directory on Accept for New Files

```lua
local function accept(session)
  -- Create directory if it is a new file
  local dir = vim.fn.fnamemodify(session.new_file_path, ":h")
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")  -- Create including intermediate directories
  end

  -- Write file
  local lines = vim.split(session.new_file_contents, "\n", { plain = true })
  vim.fn.writefile(lines, session.new_file_path)
  -- ...
end
```

## Acceptance Criteria

- [ ] New file diff: old buffer is empty, everything shows as "added" (DIF-05)
- [ ] Dirty buffer: old side shows disk contents, buffer modifications are ignored
- [ ] BufWinLeave: closing the diff window → DIFF_REJECTED response is sent
- [ ] Identical content: diff is shown but without highlighting, both Accept/Reject work
- [ ] Readonly protection: editing the proposed buffer → Neovim error message (DIF-08)
- [ ] New file Accept: parent directories are created automatically
- [ ] Cleanup works correctly after BufWinLeave

## Reference Specs

- [06-diff-ui.md](../06-diff-ui.md) Section 6.8 — Edge cases
- DIF-05: Closing diff window → reject handling
- DIF-08: Proposed buffer is read-only

## Estimated Time: ~2 hours
