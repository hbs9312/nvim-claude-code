# Phase 3-09: Diff Accept/Reject UX Improvements

## Status: Complete

## Goal

Improve the diff UI's accept/reject behavior to be more visually intuitive.

## Changes

### 1. Highlight Group Definitions

Define 8 custom highlight groups via `setup_highlights()` (user-overridable with `default=true`):

| Highlight Group | Purpose | Default |
|---|---|---|
| `ClaudeCodeDiffIndex` | Progress `[n]` badge | link → `Title` |
| `ClaudeCodeDiffOriginal` | "Original:" label | link → `Comment` |
| `ClaudeCodeDiffProposed` | "Proposed:" label | link → `Function` |
| `ClaudeCodeDiffAcceptHint` | Accept keymap hint | green bold |
| `ClaudeCodeDiffRejectHint` | Reject keymap hint | red bold |
| `ClaudeCodeDiffHintDim` | Separator `|` | link → `NonText` |
| `ClaudeCodeDiffAccepted` | Accept feedback message | green on dark green bg |
| `ClaudeCodeDiffRejected` | Reject feedback message | red on dark red bg |

### 2. Winbar Color Formatting

Apply colors to the winbar using `%#HlGroup#` statusline syntax:
- `[n]` → `ClaudeCodeDiffIndex`
- "Original:" → `ClaudeCodeDiffOriginal`
- "Proposed:" → `ClaudeCodeDiffProposed`
- Accept hint → `ClaudeCodeDiffAcceptHint` (green bold)
- Reject hint → `ClaudeCodeDiffRejectHint` (red bold)
- `%=` for right-aligning hints

### 3. Accept/Reject Feedback Flash

Instead of closing immediately on accept/reject:
1. Replace winbar with `✓ Accepted: file.lua` / `✗ Rejected: file.lua`
2. Notify the user via `vim.notify`
3. Cleanup after `feedback_delay` (default 800ms)

The MCP response (`send_response`) is sent before the feedback, so the delay does not block the Claude CLI.

### 4. Remove Keymaps During Feedback

Immediately after `session.resolved = true`, remove accept/reject keymaps from both buffers via `pcall(vim.keymap.del, ...)` to prevent duplicate inputs.

### 5. Config Additions

```lua
diff = {
  auto_close = true,
  feedback_delay = 800,  -- ms, 0 for immediate close
  keymaps = {
    accept = { "<CR>", "ga" },
    reject = { "q", "gx" },
  },
},
```

## Modified Files

| File | Changes |
|------|---------|
| `lua/claude-code/diff.lua` | Highlight definitions, winbar format, feedback flash, keymap removal |
| `lua/claude-code/config.lua` | Add `feedback_delay` default value |

## Verification Method

1. Connect Claude CLI with `:ClaudeCode`
2. Ask Claude to modify a file → triggers openDiff
3. Verify winbar colors in the diff UI (accept=green, reject=red)
4. Accept with `ga` or `<CR>` → verify "✓ Accepted" flash + vim.notify
5. Reject with `q` or `gx` → verify "✗ Rejected" flash + vim.notify
6. Verify immediate close when `feedback_delay = 0`
