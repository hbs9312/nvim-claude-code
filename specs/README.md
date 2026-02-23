# nvim-claude-code Requirements Specification

## Reference Specs (unchanged)

| # | Document | Contents |
|---|----------|----------|
| 01 | [Project Overview](01-overview.md) | Purpose, architecture, technology stack |
| 02 | [Connection and Authentication](02-connection.md) | WebSocket server, lock file, authentication, environment variables |
| 03 | [MCP Protocol](03-mcp-protocol.md) | JSON-RPC 2.0, MCP initialization, method list |
| 04 | [MCP Tools Detail](04-tools.md) | Input/output specs for 12 tools (openDiff, openFile, etc.) |
| 05 | [Notification](05-notifications.md) | selection_changed, at_mentioned, diagnostics_changed |
| 06 | [Diff UI Design](06-diff-ui.md) | openDiff Neovim UI implementation, multi-file sequential diff |
| 07 | [Plugin API](07-plugin-api.md) | setup(), commands, Lua API, module structure |

## Implementation Phases (per-phase folders)

| Phase | Folder | Status | Description |
|-------|--------|--------|-------------|
| 0 | [phase-0-infrastructure/](phase-0-infrastructure/) | Completed | Foundation infrastructure (WebSocket, MCP, lock file) |
| 1 | [phase-1-core-tools/](phase-1-core-tools/) | Pending | Core tools (openFile, openDiff, selection, diagnostics) |
| 2 | [phase-2-supporting-tools/](phase-2-supporting-tools/) | Pending | Supporting tools and stabilization |
| 3 | [phase-3-ux-polish/](phase-3-ux-polish/) | Pending | UX improvements (UX, performance, documentation) |

### Dependency Graph

```
Phase 0 (Foundation) ✅
  │
Phase 1 (Core) ←── Requires Phase 0 completion
  │
Phase 2 (Supporting) ←── Requires Phase 1 completion
  │
Phase 3 (Improvements) ←── Requires Phase 2 completion
```

Each phase folder's README.md contains detailed dependency graphs and subtask lists.

## Reference Documents (docs/)

| Document | Description |
|----------|-------------|
| [claude-code-ide-protocol.md](../docs/claude-code-ide-protocol.md) | IDE integration protocol spec (based on claudecode.nvim) |
| [vscode-extension-analysis.md](../docs/vscode-extension-analysis.md) | VS Code extension reverse engineering analysis |
| [protocol-vs-actual-diff.md](../docs/protocol-vs-actual-diff.md) | Differences between protocol documentation and actual implementation |

