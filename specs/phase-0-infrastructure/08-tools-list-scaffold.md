# Phase 0-08: tools/list Empty Registry, tools/call Dispatch

## Status: Completed

## Purpose

Respond with an empty tool list to `tools/list` requests and prepare a framework for dispatching `tools/call` requests to tool handlers. Build a registry pattern that allows actual tools to be registered in Phase 1.

## Dependencies

- 07-mcp-handshake (completed) -- Process tools/ requests after MCP initialization is complete

## Input

- `tools/list` request:
  ```json
  {
    "jsonrpc": "2.0",
    "id": "req-2",
    "method": "tools/list",
    "params": {}
  }
  ```
- `tools/call` request:
  ```json
  {
    "jsonrpc": "2.0",
    "id": "req-3",
    "method": "tools/call",
    "params": {
      "name": "toolName",
      "arguments": { ... }
    }
  }
  ```

## Output

- `tools/list` response:
  ```json
  {
    "jsonrpc": "2.0",
    "id": "req-2",
    "result": {
      "tools": []
    }
  }
  ```
- `tools/call` response (tool exists):
  ```json
  {
    "jsonrpc": "2.0",
    "id": "req-3",
    "result": {
      "content": [
        { "type": "text", "text": "result" }
      ]
    }
  }
  ```
- `tools/call` error (unregistered tool):
  ```json
  {
    "jsonrpc": "2.0",
    "id": "req-3",
    "error": {
      "code": -32601,
      "message": "Tool not found: toolName"
    }
  }
  ```

## Implementation Plan

1. **Tool Registry** (`mcp.lua` or `tools/init.lua`)
   - Tool table: `{ [name] = { schema = ..., handler = function } }`
   - `register_tool(name, schema, handler)` function
   - Empty table in Phase 0 (no tools)
2. **Register tools/list handler**
   - Register `"tools/list"` handler in the JSON-RPC router
   - Generate tool list from the registry
   - Return each tool's `name`, `description`, `inputSchema`
   - Phase 0: return empty array `{ tools = {} }`
3. **Register tools/call handler**
   - Register `"tools/call"` handler in the JSON-RPC router
   - Look up tool from registry by `params.name`
   - Tool exists: invoke `handler(params.arguments)`, wrap result in MCP content format
   - Tool not found: -32601 error response
4. **MCP Content Format**
   - Success: `{ content = { { type = "text", text = result } } }`
   - Error: `{ content = { { type = "text", text = error_msg } }, isError = true }`

## Acceptance Criteria

- [x] `tools/list` request returns empty array response (`{ tools = {} }`)
- [x] `tools/call` with an unregistered tool name returns error response
- [x] `register_tool()` function exists in the tool registry
- [x] Structure is ready so that tools registered in the registry are reflected in `tools/list`
- [x] Claude CLI calls `tools/list` and receives the empty list

## Reference Specs

- `specs/03-mcp-protocol.md` section 3.2 (initialization sequence: tools/list, tools/call)
- `specs/03-mcp-protocol.md` section 3.4 (MCP-03: tools/list, MCP-04: tools/call)
- `specs/04-tools.md` (schema reference for tools to be implemented in Phase 1)

## Estimated Time: ~1 hour
