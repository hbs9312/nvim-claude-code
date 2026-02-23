# Phase 3-04: Diff Keymap Customization

## Status: ✅ Complete

## Purpose

Allow users to customize diff accept/reject keymaps when calling `setup()`. Users should be able to change keymaps if the defaults conflict with their existing keymaps.

## Dependencies

- [x] Phase 0: Foundation Infrastructure (Complete)
- [ ] Phase 1: Core Tools (Required, Incomplete) - especially 06 diff UI
- [ ] Phase 2: Auxiliary Tools (Required, Incomplete)

## Input

- `diff.keymaps` table in `setup()` configuration
  ```lua
  require("claude-code").setup({
    diff = {
      keymaps = {
        accept = "<leader>da",  -- default: "ga"
        reject = "<leader>dr",  -- default: "gr"
      },
    },
  })
  ```

## Output

- Diff accept/reject works with user-specified keymaps
- Defaults are preserved when not specified

## Implementation Plan

1. **Extend config schema**
   - Define `config.diff.keymaps` table
   - Defaults: `{ accept = "ga", reject = "gr" }` (or keep existing defaults)

2. **Modify keymap setup logic**
   - Read keys from `config.diff.keymaps` instead of hardcoded keymaps when creating diff buffers
   - `vim.keymap.set("n", config.diff.keymaps.accept, accept_fn, { buffer = bufnr })`
   - `vim.keymap.set("n", config.diff.keymaps.reject, reject_fn, { buffer = bufnr })`

3. **Configuration validation**
   - Use defaults for empty strings or nil inputs
   - Use `vim.deep_extend("force", defaults, user_config)` pattern

## Verification Criteria

- [ ] Custom keymaps work correctly in diff buffers
- [ ] Default keymaps are preserved when not configured
- [ ] Partial configuration (changing only accept) preserves defaults for the rest
- [ ] Empty configuration `{}` uses defaults
- [ ] Invalid keymap values fall back to defaults without errors

## Reference Specs

- `07-plugin-api.md` Section 7.1 (`diff.keymaps`)
- `06-diff-ui.md` Section 6.5

## Estimated Time: ~1 hour
