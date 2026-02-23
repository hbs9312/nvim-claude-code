# Phase 1-05: vsplit Layout, diffthis

## Status: ✅ Complete

## Purpose

Arrange the old/new scratch buffers in a left-right vsplit and apply Neovim's built-in `diffthis` to create a visual diff view. This lets the user compare the original and the proposed changes side by side.

## Dependencies

- [x] Phase 0: Foundation Infrastructure (complete)
- [ ] Phase 1-01: Tool Registration System (required, incomplete)
- [ ] Phase 1-04: Create Scratch Buffers for Diff (required, incomplete)

## Input

- old buffer (created in Phase 1-04)
- new buffer (created in Phase 1-04)
- tab_name (optional, for display)

## Output

- Left window: original (old) buffer, diff mode
- Right window: proposed (new) buffer, diff mode
- Diff highlighting enabled (color-coded additions/deletions/changes)
- Scroll synchronization

## Implementation Plan

### File: `lua/claude-code/diff.lua` (extending existing)

1. **Save current layout**
   ```lua
   -- Save current state for restoration
   session.saved_layout = {
     win = vim.api.nvim_get_current_win(),
     buf = vim.api.nvim_get_current_buf(),
     -- Additional layout information (window arrangement, etc.)
   }
   ```

2. **Configure vsplit layout**
   ```lua
   -- Left: original buffer
   vim.cmd("vsplit")
   local old_win = vim.api.nvim_get_current_win()
   vim.api.nvim_win_set_buf(old_win, session.old_buf)

   -- Right: proposed buffer
   vim.cmd("wincmd l")  -- or move to the new window
   local new_win = vim.api.nvim_get_current_win()
   vim.api.nvim_win_set_buf(new_win, session.new_buf)
   ```

3. **Apply diffthis**
   ```lua
   -- Set diff mode on both windows
   vim.api.nvim_set_current_win(old_win)
   vim.cmd("diffthis")

   vim.api.nvim_set_current_win(new_win)
   vim.cmd("diffthis")
   ```

4. **winbar display**
   ```lua
   -- Show filename in each window
   vim.wo[old_win].winbar = "  Original: " .. filename
   vim.wo[new_win].winbar = "  Proposed: " .. filename .. "  [<CR>: Accept | q: Reject]"
   ```

5. **Focus setting**
   - Focus the proposed (new) window → user sees the changes first

6. **Save session state**
   ```lua
   session.old_win = old_win
   session.new_win = new_win
   ```

## Acceptance Criteria

- [ ] Original is displayed on the left, proposed on the right (DIF-01)
- [ ] Diff highlighting works: additions (green), deletions (red), changes (blue) (DIF-02)
- [ ] Scroll is synchronized between both windows
- [ ] winbar shows the filename and Accept/Reject hints
- [ ] `]c`/`[c` navigates to the next/previous change (built-in Neovim)
- [ ] Focus is on the proposed (right) window

## Reference Specs

- [06-diff-ui.md](../06-diff-ui.md) Section 6.3 (steps 1, 4) — Layout save, vsplit
- [06-diff-ui.md](../06-diff-ui.md) Section 6.6 — Status display
- DIF-01: Left-right split display
- DIF-02: diffthis highlighting

## Estimated Time: ~2 hours
