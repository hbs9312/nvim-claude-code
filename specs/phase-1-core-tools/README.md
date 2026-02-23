# Phase 1: Core Tools

## Status: ✅ Complete

> Requires full completion of Phase 0

## Goal

Implement core tools that allow Claude to open files, propose edits, and let the user accept/reject them.

When Phase 1 is complete:
- Tell Claude "open file X" → the file opens in Neovim
- Tell Claude "fix this function" → proposed edits are shown in a diff view
- Accept → file is saved, FILE_SAVED is sent to Claude
- Reject → original is preserved, DIFF_REJECTED is sent to Claude
- Claude recognizes the editor selection
- Claude recognizes LSP errors and proposes fixes

## Dependencies

- [x] Phase 0: Foundation Infrastructure (must be complete)
  - Phase 0-01 ~ 0-10: WebSocket server, MCP protocol, JSON-RPC, etc.

## Subtask List

| # | File | Title | Cluster | Estimated Time |
|---|------|-------|---------|----------------|
| 01 | 01-tool-registry.md | Tool Registration System | Foundation | ~2 hours |
| 02 | 02-open-file-basic.md | openFile: Open File by Path | A (openFile) | ~1 hour |
| 03 | 03-open-file-range.md | openFile: startText/endText Range Selection | A (openFile) | ~1 hour |
| 04 | 04-diff-buffer-setup.md | Create Scratch Buffers for Diff | B (diff) | ~2 hours |
| 05 | 05-diff-layout.md | vsplit Layout, diffthis | B (diff) | ~2 hours |
| 06 | 06-diff-accept-reject.md | Accept/Reject Keymaps, Blocking Response | B (diff) | ~2 hours |
| 07 | 07-diff-cleanup.md | diffoff, bwipeout, Layout Restoration | B (diff) | ~1 hour |
| 08 | 08-diff-edge-cases.md | New File, Dirty Buffer, BufWinLeave | B (diff) | ~2 hours |
| 09 | 09-selection-tracking.md | CursorMoved Tracking, Cache | C (selection) | ~2 hours |
| 10 | 10-get-current-selection.md | getCurrentSelection Tool | C (selection) | ~1 hour |
| 11 | 11-get-latest-selection.md | getLatestSelection Tool | C (selection) | ~0.5 hours |
| 12 | 12-get-diagnostics.md | getDiagnostics Tool (LSP) | D (diagnostics) | ~1.5 hours |
| 13 | 13-selection-changed.md | selection_changed Notification | C (selection) | ~1 hour |

**Total Estimated Time: ~19 hours**

## Dependency Graph

```
01-tool-registry
 ├── 02-open-file-basic → 03-open-file-range
 ├── 04-diff-buffer-setup → 05-diff-layout → 06-diff-accept-reject → 07-diff-cleanup → 08-diff-edge-cases
 ├── 09-selection-tracking → 10-get-current-selection
 │                        → 11-get-latest-selection
 │                        → 13-selection-changed
 └── 12-get-diagnostics
```

## Parallel Clusters

After 01-tool-registry is complete, the following 4 clusters can proceed **in parallel**:

| Cluster | Name | Subtasks | Description |
|---------|------|----------|-------------|
| A | openFile | 02 → 03 | File opening + range selection |
| B | diff | 04 → 05 → 06 → 07 → 08 | Full diff view flow |
| C | selection | 09 → {10, 11, 13} | Selection tracking and notifications |
| D | diagnostics | 12 | LSP diagnostics (independent) |

```
                    ┌─ A: 02 → 03
                    │
01-tool-registry ──┼─ B: 04 → 05 → 06 → 07 → 08
                    │
                    ├─ C: 09 → ┬─ 10
                    │          ├─ 11
                    │          └─ 13
                    │
                    └─ D: 12
```

## Acceptance Criteria

- [ ] Tell Claude "open file X" → the file opens in Neovim
- [ ] Tell Claude "fix this function" → proposed edits are shown in a diff view
- [ ] Accept → file is saved, FILE_SAVED is sent to Claude
- [ ] Reject → original is preserved, DIFF_REJECTED is sent to Claude
- [ ] Claude recognizes the editor selection
- [ ] Claude recognizes LSP errors and proposes fixes

## Reference Specs

- [03-mcp-protocol.md](../03-mcp-protocol.md) - MCP Protocol (tools/list, tools/call)
- [04-tools.md](../04-tools.md) - Tool Detailed Specs
- [05-notifications.md](../05-notifications.md) - Notification Specs
- [06-diff-ui.md](../06-diff-ui.md) - Diff UI Design
