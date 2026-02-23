# Phase 0-03: WebSocket Upgrade Handshake, Authentication Verification

## Status: Completed

## Purpose

Parse the HTTP Upgrade request from a TCP connection and perform the WebSocket handshake. Verify the `x-claude-code-ide-authorization` header to allow only authenticated clients to connect.

## Dependencies

- 02-tcp-server (completed) -- Data reception after TCP connection establishment required

## Input

- HTTP Upgrade request (raw bytes)
  - `GET / HTTP/1.1`
  - `Upgrade: websocket`
  - `Connection: Upgrade`
  - `Sec-WebSocket-Key: <base64>`
  - `Sec-WebSocket-Version: 13`
  - `x-claude-code-ide-authorization: <authToken>`

## Output

- Success: WebSocket connection established (HTTP 101 Switching Protocols response)
- Failure: Connection rejected (WebSocket close 1008 "Unauthorized" or HTTP 400)

## Implementation Plan

1. Implement HTTP request parser in `websocket.lua`
   - Extract method, path, and protocol from the first line
   - Parse headers (key: value format)
2. Validate WebSocket Upgrade request
   - Verify `Upgrade: websocket` header
   - Verify `Connection: Upgrade` header
   - Verify `Sec-WebSocket-Version: 13`
   - Verify `Sec-WebSocket-Key` exists
3. Authentication verification
   - Extract token from `x-claude-code-ide-authorization` header
   - Compare with `authToken` recorded in the lock file
   - On mismatch, send WebSocket close(1008, "Unauthorized") and terminate connection
4. Calculate `Sec-WebSocket-Accept`
   - Concatenate `Sec-WebSocket-Key` + `"258EAFA5-E914-47DA-95CA-C5AB0DC85B11"`
   - Compute SHA-1 hash
   - Base64 encode
5. Send HTTP 101 Switching Protocols response
   ```
   HTTP/1.1 101 Switching Protocols\r\n
   Upgrade: websocket\r\n
   Connection: Upgrade\r\n
   Sec-WebSocket-Accept: <calculated>\r\n
   \r\n
   ```
6. Switch to WebSocket frame mode after handshake completion

## Acceptance Criteria

- [x] HTTP Upgrade request parsing works correctly
- [x] Handshake succeeds with valid `authToken` (HTTP 101 response)
- [x] `Sec-WebSocket-Accept` value is calculated per RFC 6455 specification
- [x] Connection attempt with invalid `authToken` is rejected (close 1008)
- [x] Missing `x-claude-code-ide-authorization` header is rejected
- [x] Invalid HTTP request (not an Upgrade) returns HTTP 400 response

## Reference Specs

- `specs/02-connection.md` section 2.3 (AUTH-01 ~ AUTH-03)
- `specs/02-connection.md` section 2.5 (full connection sequence, steps 7~8)
- RFC 6455 section 4.2 (Opening Handshake)

## Estimated Time: ~3 hours
