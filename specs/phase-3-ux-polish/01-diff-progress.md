# Phase 3-01: Diff Progress Indicator (n/m)

## Status: ✅ Complete

## Purpose

Display the current progress in [n/m] format during multi-file diffs, so users can easily see which file they are reviewing out of the total.

## Dependencies

- [x] Phase 0: Foundation Infrastructure (Complete)
- [ ] Phase 1: Core Tools (Required, Incomplete) - especially 04-08 diff implementation
- [ ] Phase 2: Auxiliary Tools (Required, Incomplete)

## Input

- openDiff call sequence (consecutive openDiff calls during multi-file diffs)

## Output

- Progress displayed in the winbar or statusline as `[1/3] Proposed: file.lua`
- Even for single-file diffs, displayed as `[1/1] Proposed: file.lua`

## Implementation Plan

1. **Track diff session index**
   - Add current_index and total_count fields to the diff session manager
   - Increment index on each openDiff call, set total count at session start

2. **Winbar configuration**
   - Set the progress format string in the diff buffer's winbar
   - Format: `vim.wo[win].winbar = "[n/m] Proposed: filename"`

3. **Progress updates**
   - Automatically update winbar when moving to the next diff after accept/reject
   - Restore winbar when all diffs are complete

## Verification Criteria

- [ ] Progress is displayed in `[n/m]` format during multi-file diffs
- [ ] Displayed as `[1/1]` even for single-file diffs
- [ ] Index increments correctly when moving to the next diff after accept/reject
- [ ] Winbar is cleaned up after all diffs are complete

## Reference Specs

- `06-diff-ui.md` Section 6.6
- DIF-07

## Estimated Time: ~1 hour
