# 01. Project Overview

## 1.1 Project Name

**nvim-claude-code** — Claude Code IDE integration plugin for Neovim

## 1.2 Purpose

Enable bidirectional communication between Claude Code CLI and Neovim, providing an IDE integration experience equivalent to the VS Code extension.

## 1.3 Scope

Implement the WebSocket/MCP protocol between Claude Code CLI and Neovim to:
- Allow Claude to query Neovim's file/editor state
- Display Claude's proposed code changes in a diff view with accept/reject functionality
- Provide Neovim's LSP diagnostic information to Claude

## 1.4 Architecture Overview

```
┌──────────────┐  WebSocket (JSON-RPC 2.0 / MCP)  ┌───────────────┐
│   Neovim     │◄─────────────────────────────────►│ Claude Code   │
│  (MCP Server)│     localhost:random_port          │  CLI (Client) │
└──────┬───────┘                                   └───────────────┘
       │
       ├── Lock file (~/.claude/ide/{port}.lock)
       ├── MCP Tool handlers (10~12)
       ├── Notification sending (selection_changed, at_mentioned, diagnostics_changed)
       └── Diff UI (split window, accept/reject)
```

## 1.5 Technology Stack

| Item | Choice |
|------|--------|
| Language | Lua (Neovim Lua API) |
| Minimum Neovim version | 0.10+ (to be finalized) |
| WebSocket | Pure Lua implementation or `vim.uv` (libuv) based |
| JSON-RPC | Custom implementation (MCP spec compliant) |
| Diff UI | Neovim built-in diff (`diffthis`) |

## 1.6 Reference Documents

| Document | Path | Description |
|----------|------|-------------|
| IDE protocol spec | `docs/claude-code-ide-protocol.md` | Based on claudecode.nvim PROTOCOL.md |
| VS Code extension analysis | `docs/vscode-extension-analysis.md` | extension.js reverse engineering |
| Protocol differences | `docs/protocol-vs-actual-diff.md` | Documentation vs actual implementation comparison |

## 1.7 Reference Projects

| Project | URL | Notes |
|---------|-----|-------|
| claudecode.nvim (coder) | github.com/coder/claudecode.nvim | Existing community implementation. Source of protocol documentation |
