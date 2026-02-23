# Phase 0-07: MCP initialize/initialized Handler

## Status: Completed

## Purpose

Respond with server capabilities to the MCP `initialize` request and handle the `initialized` notification. MCP communication with Claude CLI begins only after this handshake is completed.

## Dependencies

- 06-json-rpc-parser (completed) -- JSON-RPC method dispatch framework required

## Input

- `initialize` request:
  ```json
  {
    "jsonrpc": "2.0",
    "id": "req-1",
    "method": "initialize",
    "params": {
      "protocolVersion": "2025-03-26",
      "capabilities": {},
      "clientInfo": {
        "name": "claude-code",
        "version": "1.0.0"
      }
    }
  }
  ```
- `notifications/initialized` notification:
  ```json
  {
    "jsonrpc": "2.0",
    "method": "notifications/initialized"
  }
  ```

## Output

- `initialize` response:
  ```json
  {
    "jsonrpc": "2.0",
    "id": "req-1",
    "result": {
      "protocolVersion": "2025-03-26",
      "capabilities": {
        "tools": {}
      },
      "serverInfo": {
        "name": "Claude Code Neovim MCP",
        "version": "0.1.0"
      }
    }
  }
  ```
- Transition internal state to "connected" upon receiving the `initialized` notification

## Implementation Plan

1. **Register initialize handler** (`mcp.lua`)
   - Register `"initialize"` method handler in the JSON-RPC router
   - Check `params.protocolVersion` (currently fixed to `"2025-03-26"`)
   - Store `params.clientInfo` (for later status queries)
   - Compose response result:
     - `protocolVersion`: `"2025-03-26"`
     - `capabilities`: `{ tools = {} }` (declare tool support)
     - `serverInfo`: `{ name = "Claude Code Neovim MCP", version = "0.1.0" }`
2. **Register initialized handler**
   - Register `"notifications/initialized"` handler in the JSON-RPC router
   - Set internal connection state to "initialized"
   - Emit `ClaudeCodeClientConnected` User autocmd event
3. **State Management**
   - Connection states: `"waiting"` -> `"initializing"` (initialize received) -> `"ready"` (initialized received)
   - Query state via `is_connected()` function

## Acceptance Criteria

- [x] Correct response returned upon `initialize` request reception
- [x] `protocolVersion` set to `"2025-03-26"`
- [x] `capabilities` includes `tools: {}`
- [x] `serverInfo.name` is `"Claude Code Neovim MCP"`
- [x] `serverInfo.version` is `"0.1.0"`
- [x] Internal state transitions after `notifications/initialized` reception
- [x] Claude CLI sends initialized after initialize, then requests tools/list

## Reference Specs

- `specs/03-mcp-protocol.md` section 3.2 (MCP-01 ~ MCP-05, initialization sequence)
- `specs/03-mcp-protocol.md` section 3.4 (supported methods: initialize, notifications/initialized)
- `specs/02-connection.md` section 2.5 (full connection sequence, step 9)

## Estimated Time: ~1 hour
