# Phase 2: Supporting Tools and Stabilization

## Status: Pending

To be started after Phase 1 (Core Tools) is complete.

## Goal

Complete the tool set to match feature parity with the VS Code extension. In addition to the core tools implemented in Phase 1 (openDiff, openFile, selection, diagnostics), implement the remaining supporting tools, notifications, commands, error handling, and logging.

## Included Specs

| # | File | Title | Type | Estimated Time |
|---|------|-------|------|----------------|
| 01 | 01-get-open-editors.md | getOpenEditors tool | MCP Tool | ~1 hour |
| 02 | 02-get-workspace-folders.md | getWorkspaceFolders tool | MCP Tool | ~0.5 hours |
| 03 | 03-check-document-dirty.md | checkDocumentDirty tool | MCP Tool | ~0.5 hours |
| 04 | 04-save-document.md | saveDocument tool | MCP Tool | ~0.5 hours |
| 05 | 05-close-all-diff-tabs.md | closeAllDiffTabs tool | MCP Tool | ~1 hour |
| 06 | 06-close-tab.md | close_tab tool | MCP Tool | ~0.5 hours |
| 07 | 07-at-mentioned.md | at_mentioned notification + :ClaudeAtMention | Notification/Command | ~1 hour |
| 08 | 08-diagnostics-changed.md | diagnostics_changed notification | Notification | ~1 hour |
| 09 | 09-commands.md | :ClaudeCodeStatus/Stop/Restart enhancement | Command | ~1.5 hours |
| 10 | 10-error-handling.md | pcall wrapper, error recovery | Infrastructure | ~2 hours |
| 11 | 11-logging.md | Structured logging, :ClaudeCodeLog | Infrastructure/Command | ~1.5 hours |

**Total estimated time: ~11 hours**

## Dependencies

```
Phase 0: Foundation Infrastructure (must be completed)
  └── WebSocket server, JSON-RPC, MCP handshake, Lock file

Phase 1: Core Tools (must be completed)
  └── tool-registry (tools/init.lua), diff UI (diff.lua), selection cache

Phase 2: Supporting Tools (this Phase)
  ├── 01~06: MCP Tools → Register in Phase 1's tool-registry
  ├── 07~08: Notifications → Depends on Phase 0's WebSocket transport
  ├── 09: Commands → Depends on Phase 0's server base behavior
  ├── 10: Error handling → After all of Phase 1 is complete
  └── 11: Logging → Depends on Phase 0's base structure
```

Most specs are independent of each other and can be implemented in parallel. However, 10-error-handling is most efficiently applied after all tools have been implemented.

## Acceptance Criteria

1. All 12 tools are confirmed registered in the `tools/list` response (close_tab without description)
2. Each tool responds in the correct format as defined in 04-tools.md
3. When Claude modifies multiple files sequentially, diffs are displayed in order
4. Stable behavior on abnormal termination/reconnection (no crashes, no resource leaks)
5. :ClaudeCodeStatus displays accurate status information
6. Structured logs can be viewed via :ClaudeCodeLog
7. All tool errors return JSON-RPC error responses (no Neovim crashes)

## Reference Specs

- [04-tools.md](../04-tools.md) - Tool detailed spec (sections 4.7~4.12)
- [05-notifications.md](../05-notifications.md) - Notification spec (sections 5.2~5.3)
- [07-plugin-api.md](../07-plugin-api.md) - Commands and API spec (sections 7.1~7.2)
- [03-mcp-protocol.md](../03-mcp-protocol.md) - MCP protocol and error codes (section 3.5)
- [08-implementation-phases.md](../08-implementation-phases.md) - Phase 2 scope definition
