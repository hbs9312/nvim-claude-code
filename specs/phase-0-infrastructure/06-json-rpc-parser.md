# Phase 0-06: JSON-RPC 2.0 Dispatch, Error Codes

## Status: Completed

## Purpose

Parse JSON-RPC 2.0 messages and dispatch them to the appropriate handler based on the method. Handle standard error codes to return spec-compliant error responses for invalid requests.

## Dependencies

- 04-websocket-frames (completed) -- JSON message reception via WebSocket text frames required

## Input

- JSON string (payload of a WebSocket text frame)

## Output

- Parsed request object -> handler invocation
- Parsed notification object -> handler invocation (no response)
- JSON-RPC error response (parse failure, invalid request, unsupported method, etc.)

## Implementation Plan

1. **Message Parsing** (`mcp.lua`)
   - Parse JSON with `vim.json.decode()`
   - Return error response on parse failure (-32700 Parse error)
2. **Message Type Identification**
   - `id` field present + `method` field present -> Request
   - `id` field present + `result`/`error` field -> Response (currently unhandled)
   - `id` field absent + `method` field present -> Notification
3. **Validation**
   - Check `jsonrpc` field is `"2.0"` -> otherwise -32600 Invalid request
   - Check `method` field is a string -> otherwise -32600 Invalid request
4. **Method Router**
   - Handler table: `{ ["initialize"] = handler, ["tools/list"] = handler, ... }`
   - Unregistered method -> -32601 Method not found
   - Pass `params` when invoking the handler
5. **Error Response Generation**
   ```lua
   {
     jsonrpc = "2.0",
     id = request_id,  -- vim.NIL on parse failure
     error = {
       code = error_code,
       message = error_message
     }
   }
   ```
6. **Standard Error Codes**
   | Code | Meaning | Trigger Condition |
   |------|---------|-------------------|
   | -32700 | Parse error | JSON parse failure |
   | -32600 | Invalid request | jsonrpc != "2.0" or structural error |
   | -32601 | Method not found | Unregistered method |
   | -32602 | Invalid params | Missing required parameters or type error |
   | -32603 | Internal error | Exception during handler execution |

## Acceptance Criteria

- [x] Valid JSON-RPC request parsed and handler invoked
- [x] Valid notification parsed and handler invoked (no response)
- [x] Invalid JSON -> -32700 Parse error response
- [x] Missing/mismatched jsonrpc field -> -32600 Invalid request response
- [x] Unregistered method -> -32601 Method not found response
- [x] Error during handler execution -> -32603 Internal error response
- [x] Response JSON contains the correct `id` (same as the request's id)

## Reference Specs

- `specs/03-mcp-protocol.md` section 3.3 (message structure: Request, Response, Error, Notification)
- `specs/03-mcp-protocol.md` section 3.5 (error codes: -32700 ~ -32603)
- JSON-RPC 2.0 Specification (https://www.jsonrpc.org/specification)

## Estimated Time: ~2 hours
