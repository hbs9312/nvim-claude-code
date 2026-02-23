# Phase 1-07: diffoff, bwipeout, Layout Restoration

## Status: ✅ Complete

## Purpose

Cleanly restore the Neovim state after a diff is completed (accept/reject). This involves disabling diff mode, deleting scratch buffers, removing keymaps and autocmds, and restoring the original window layout.

## Dependencies

- [x] Phase 0: Foundation Infrastructure (complete)
- [ ] Phase 1-01: Tool Registration System (required, incomplete)
- [ ] Phase 1-04: Create Scratch Buffers for Diff (required, incomplete)
- [ ] Phase 1-05: vsplit Layout (required, incomplete)
- [ ] Phase 1-06: Accept/Reject Keymaps (required, incomplete)

## Input

Diff session completion signal (called after accept or reject)

## Output

A clean editor state:
- Diff mode disabled
- Scratch buffers deleted
- Keymaps removed
- Autocmds removed
- Original window layout restored

## Implementation Plan

### File: `lua/claude-code/diff.lua` (extending existing)

1. **Disable diff mode**
   ```lua
   local function cleanup(session)
     -- Disable diff on both windows
     if vim.api.nvim_win_is_valid(session.old_win) then
       vim.api.nvim_set_current_win(session.old_win)
       vim.cmd("diffoff")
     end
     if vim.api.nvim_win_is_valid(session.new_win) then
       vim.api.nvim_set_current_win(session.new_win)
       vim.cmd("diffoff")
     end
   ```

2. **Delete scratch buffers**
   ```lua
     -- Completely delete with bwipeout (also possible by closing windows since bufhidden=wipe)
     if vim.api.nvim_buf_is_valid(session.old_buf) then
       vim.api.nvim_buf_delete(session.old_buf, { force = true })
     end
     if vim.api.nvim_buf_is_valid(session.new_buf) then
       vim.api.nvim_buf_delete(session.new_buf, { force = true })
     end
   ```

3. **Remove autocmds**
   ```lua
     -- Delete diff-related autocmd group (e.g., BufWinLeave)
     if session.augroup then
       vim.api.nvim_del_augroup_by_id(session.augroup)
     end
   ```

4. **Restore window layout**
   ```lua
     -- Restore to saved layout
     if session.saved_layout and vim.api.nvim_win_is_valid(session.saved_layout.win) then
       vim.api.nvim_set_current_win(session.saved_layout.win)
       -- Switch to saved buffer if still valid
       if vim.api.nvim_buf_is_valid(session.saved_layout.buf) then
         vim.api.nvim_win_set_buf(session.saved_layout.win, session.saved_layout.buf)
       end
     end
   end
   ```

5. **Reset session state**
   ```lua
   -- Remove current diff session reference
   M._current_session = nil
   ```

6. **When cleanup is called**
   - At the end of accept/reject functions in Phase 1-06
   - From the BufWinLeave safety guard in Phase 1-08

## Acceptance Criteria

- [ ] Diff mode is disabled (diffoff) after Accept/Reject
- [ ] Scratch buffers (old, new) are completely deleted (bwipeout)
- [ ] Diff-related autocmds are removed
- [ ] Original window layout is restored
- [ ] After cleanup, no diff-related buffers appear in `:ls`
- [ ] No errors on duplicate cleanup calls (validity checks)

## Reference Specs

- [06-diff-ui.md](../06-diff-ui.md) Section 6.7 — Cleanup

## Estimated Time: ~1 hour
