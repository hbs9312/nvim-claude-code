# 06. Diff UI Design

## 6.1 Overview

Neovim UI implementation for the `openDiff` tool. An interface for visually reviewing and accepting/rejecting code changes proposed by Claude.

## 6.2 Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| DIF-01 | Display original (left) / proposed (right) in a side-by-side split | Required |
| DIF-02 | Apply Neovim built-in diff highlighting (`diffthis`) | Required |
| DIF-03 | Accept keymap: save proposed changes to the original file | Required |
| DIF-04 | Reject keymap: keep original, close diff window | Required |
| DIF-05 | Closing the diff window directly should be treated as reject | Required |
| DIF-06 | Allow other work while diff is displayed (non-modal recommended) | Recommended |
| DIF-07 | Status display: filename, [n/m] progress indicator (if possible) | Recommended |
| DIF-08 | Proposed buffer should be read-only (prevent user edits) | Recommended |

## 6.3 Single File Diff Flow

```
openDiff(old_file_path, new_file_path, new_file_contents, tab_name)
  │
  ├─ 1. Save current layout
  │
  ├─ 2. Prepare original buffer
  │   └─ Create scratch buffer, load old_file_path contents
  │       (If file is already open and dirty → use contents from disk)
  │
  ├─ 3. Prepare proposed buffer
  │   └─ Create scratch buffer, set new_file_contents
  │       buftype=nofile, readonly, set filetype
  │
  ├─ 4. Side-by-side split
  │   └─ vsplit → left: original buffer, right: proposed buffer
  │       Apply diffthis to both windows
  │
  ├─ 5. Set keymaps (diff buffer local)
  │   ├─ <CR> or ga → Accept
  │   ├─ q or gx   → Reject
  │   └─ ]c / [c   → Next/previous change (Neovim built-in)
  │
  ├─ 6. Set autocmd
  │   └─ BufWinLeave → treat as reject (safety net)
  │
  └─ 7. Await response (callback)
      ├─ On Accept: write file → respond "FILE_SAVED" → cleanup
      └─ On Reject: respond "DIFF_REJECTED" → cleanup
```

## 6.4 Multi-File Sequential Diff

When Claude CLI modifies multiple files, `openDiff` is called sequentially.

```
┌─────────────────────────────────────────┐
│ Claude: Modifying 3 files...            │
│                                         │
│ openDiff(file1) ──►  [show diff]        │
│                       user accepts ──►  │
│ openDiff(file2) ──►  [show diff]        │
│                       user accepts ──►  │
│ openDiff(file3) ──►  [show diff]        │
│                       user accepts ──►  │
│                                         │
│ Claude: All changes applied.            │
└─────────────────────────────────────────┘
```

### Implementation Points

- Each `openDiff` call cleans up the previous diff window and displays the new diff
- The CLI handles sequential calling itself, so no queuing is needed on the plugin side
- If no response is sent, the CLI automatically waits

## 6.5 Keymap Design

### Diff Buffer-Only Keymaps

| Key | Action | Description |
|-----|--------|-------------|
| `<CR>` | Accept | Save proposed changes to file |
| `ga` | Accept | Alternative Accept key |
| `q` | Reject | Keep original |
| `gx` | Reject | Alternative Reject key |
| `]c` | Next change | Neovim built-in diff navigation |
| `[c` | Previous change | Neovim built-in diff navigation |

> Keymaps should be customizable through user configuration.

## 6.6 Status Display

Information to show in the diff view:

```
┌─ Original: src/main.lua ──────┬─ Proposed: src/main.lua ─────┐
│  1  local M = {}              │  1  local M = {}             │
│  2  function M.hello()        │  2  function M.hello()       │
│  3 -  print("hello")          │  3 +  print("hello, world!") │
│  4  end                       │  4  end                      │
│                               │                              │
│ [Accept: <CR>]  [Reject: q]   │                              │
└───────────────────────────────┴──────────────────────────────┘
```

### Method

- Display filename + status in `winbar` or `statusline`
- Show shortcut key hints with a floating window (optional)

## 6.7 Cleanup

After diff completion:

1. Disable diff mode (`diffoff`)
2. Delete scratch buffers (`bwipeout`)
3. Remove diff-related keymaps
4. Remove autocmds
5. Restore original window layout (if possible)

## 6.8 Edge Cases

| Situation | Handling |
|-----------|----------|
| Original file does not exist (new file) | Create old buffer with empty content |
| Original file is already open and dirty | Use contents from disk as old (same behavior as VS Code) |
| new_file_contents is identical to original | Show diff but indicate no changes |
| Neovim is being shut down | No response → CLI handles via timeout |
| User tries to edit the proposed buffer | Prevent with `readonly` + `nomodifiable` |
