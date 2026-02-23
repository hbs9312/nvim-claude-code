# Phase 0: Foundation Infrastructure

## Status: Completed

## Goal

Verify that the WebSocket server and MCP handshake work correctly so that Claude CLI can connect.

## Scope

| # | Subtask | Status |
|---|---------|--------|
| 01 | Project directory structure, module skeleton | Completed |
| 02 | vim.uv TCP server bind/listen | Completed |
| 03 | WebSocket Upgrade handshake, authentication verification | Completed |
| 04 | WebSocket frame parsing/generation, ping/pong, close | Completed |
| 05 | Lock file creation/deletion, atomic write | Completed |
| 06 | JSON-RPC 2.0 dispatch, error codes | Completed |
| 07 | MCP initialize/initialized handler | Completed |
| 08 | tools/list empty registry, tools/call dispatch | Completed |
| 09 | setup() function, config validation | Completed |
| 10 | :ClaudeCode command, vsplit/external mode | Completed |

## Validation Criteria

1. Run `:ClaudeCode` in Neovim
2. Claude CLI reads the lock file and connects
3. MCP handshake succeeds
4. Claude CLI prompt appears

## Dependency Graph

```
01-project-structure
 ├──► 02-tcp-server
 │     ├──► 03-websocket-upgrade
 │     │     └──► 04-websocket-frames
 │     │           └──► 06-json-rpc-parser
 │     │                 └──► 07-mcp-handshake
 │     │                       └──► 08-tools-list-scaffold
 │     └──► 05-lockfile
 └──► 09-setup-and-config
       └──► 10-claude-code-command (+ 02-tcp-server)
```

## Reference Specs

- `specs/02-connection.md` - Connection and authentication
- `specs/03-mcp-protocol.md` - MCP protocol
- `specs/07-plugin-api.md` - Plugin API and configuration
- `specs/08-implementation-phases.md` - Implementation phases (Phase 0 section)

## Implementation Files

```
lua/claude-code/
├── init.lua        -- setup(), public API, :ClaudeCode command
├── config.lua      -- default config definition and merge logic
├── server.lua      -- vim.uv TCP server
├── websocket.lua   -- WebSocket protocol (upgrade, frame)
├── mcp.lua         -- MCP protocol (JSON-RPC, initialize, tools)
├── lockfile.lua    -- Lock file management
└── util.lua        -- UUID generation, logging, and other utility functions
```

