# Phase 0-04: WebSocket Frame Parsing/Generation, ping/pong, close

## Status: Completed

## Purpose

Implement RFC 6455 WebSocket frame reading/writing. Handle text frames (opcode 0x1), ping (opcode 0x9), pong (opcode 0xA), and close (opcode 0x8) frames. Unmask masked frames from the client, and send server frames without masking.

## Dependencies

- 03-websocket-upgrade (completed) -- Frame communication starts after WebSocket connection establishment

## Input

- Raw TCP byte stream (after WebSocket handshake completion)

## Output

- Receive: Decoded messages (text payload) and control frame handling
- Send: Encoded WebSocket frame bytes

## Implementation Plan

1. **Frame Parser** (`websocket.lua`)
   - Extract FIN, opcode, MASK, payload length from the first 2 bytes
   - Handle payload length extensions:
     - 126: next 2 bytes (16-bit)
     - 127: next 8 bytes (64-bit)
   - Read 4-byte masking key when MASK bit is set
   - Unmask: `decoded[i] = encoded[i] XOR mask[i % 4]`
2. **Frame Builder** (`websocket.lua`)
   - Server-to-client: MASK bit 0 (no masking)
   - FIN=1 (single frame, fragmentation not supported)
   - Payload length encoding (including 126/127 extensions)
3. **Text Frame (opcode 0x1)**
   - Used for JSON-RPC message send/receive
   - UTF-8 string payload
4. **Ping/Pong (opcode 0x9/0xA)**
   - Automatically respond with Pong using the same payload upon Ping reception
   - Used for keepalive
5. **Close Frame (opcode 0x8)**
   - Respond with Close and terminate TCP connection upon Close reception
   - Parse status code (2-byte big-endian)
   - Ability to send Close from server (for graceful shutdown)
6. **Buffering**
   - Accumulate incomplete frames in buffer when received from TCP stream
   - Parse and invoke callback when a complete frame is assembled

## Acceptance Criteria

- [x] Text frame send/receive works correctly
- [x] Client masked frames are decoded correctly
- [x] Server frames are sent without masking
- [x] Pong automatically responds upon Ping reception
- [x] Close response sent and connection terminated upon Close frame reception
- [x] Large payloads (126, 127 extensions) handled correctly
- [x] Incomplete frames are buffered and reassembled

## Reference Specs

- `specs/02-connection.md` section 2.1 (CON-03: RFC 6455 WebSocket protocol compliance)
- `specs/02-connection.md` section 2.6 (CLN-02: graceful WebSocket connection close)
- RFC 6455 section 5 (Data Framing)
- RFC 6455 section 5.5 (Control Frames: Close, Ping, Pong)

## Estimated Time: ~3 hours
