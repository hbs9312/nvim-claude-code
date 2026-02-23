# Phase 0-02: vim.uv TCP Server Bind/Listen

## Status: Completed

## Purpose

Create a `vim.uv` (libuv) based TCP server that listens on localhost (127.0.0.1) on a random port. Provide the foundational network layer for Claude CLI to connect via WebSocket.

## Dependencies

- 01-project-structure (completed) -- server.lua module file required

## Input

- `host`: Binding address (default `"127.0.0.1"`)
- `port`: Listen port (default `0` = OS auto-selects, range 10000~65535)

## Output

- TCP server object (`uv_tcp_t`)
- Actual bound port number

## Implementation Plan

1. Implement `M.start(host, port, on_connection)` function in `server.lua`
2. Create TCP handle with `vim.uv.new_tcp()`
3. Bind address with `tcp:bind(host, port)`
4. Wait for connections with `tcp:listen(128, on_connection_callback)`
5. Obtain actual bound port number with `tcp:getsockname()`
6. Implement `M.stop()` function for server shutdown and resource cleanup
7. Single client policy: close previous connection when a new connection arrives
8. Error handling: log output on bind failure or listen failure

## Acceptance Criteria

- [x] Server creation succeeds with `vim.uv.new_tcp()`
- [x] Binds only to localhost (127.0.0.1)
- [x] Returns auto-assigned port number when starting with port 0
- [x] TCP connections can be accepted (on_connection callback invoked)
- [x] Resources cleaned up on server shutdown (tcp:close())
- [x] Single client policy: previous connection closed when new connection arrives

## Reference Specs

- `specs/02-connection.md` section 2.1 (CON-01 ~ CON-05)
- `specs/02-connection.md` section 2.5 (full connection sequence, step 3)
- `specs/02-connection.md` section 2.6 (CLN-03: close TCP server)

## Estimated Time: ~2 hours
