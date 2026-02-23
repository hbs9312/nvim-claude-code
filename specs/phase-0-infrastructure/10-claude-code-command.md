# Phase 0-10: :ClaudeCode Command, vsplit/external Mode

## Status: Completed

## Purpose

Register the `:ClaudeCode` user command to run Claude CLI in a terminal buffer. Automatically set the environment variables (`CLAUDE_CODE_SSE_PORT`, `MCP_CONNECTION_NONBLOCKING`) required for connecting to the WebSocket server.

## Dependencies

- 09-setup-and-config (completed) -- Command registration after setup()
- 02-tcp-server (completed) -- Server port number required

## Input

- User executes the `:ClaudeCode` command
- (Optional) Additional arguments: arguments to pass to Claude CLI

## Output

- Claude CLI runs in a terminal buffer
- Environment variables set:
  - `CLAUDE_CODE_SSE_PORT`: WebSocket server port
  - `MCP_CONNECTION_NONBLOCKING`: `"true"`
- Claude CLI reads environment variables and finds the lock file to establish a WebSocket connection

## Implementation Plan

1. **Command Registration** (`init.lua`)
   - `vim.api.nvim_create_user_command("ClaudeCode", handler, opts)`
   - Register within setup()
2. **Terminal Mode Implementation**
   - vsplit terminal:
     ```lua
     vim.cmd("vsplit")
     vim.fn.termopen(cmd, { env = env_vars })
     ```
   - Environment variable setup:
     ```lua
     local env = {
       CLAUDE_CODE_SSE_PORT = tostring(port),
       MCP_CONNECTION_NONBLOCKING = "true",
     }
     ```
3. **Claude CLI Command Construction**
   - Default: `"claude"` (must be in PATH)
   - Pass additional arguments: `:ClaudeCode --help` -> `"claude --help"`
4. **Terminal Buffer Management**
   - Switch focus if an existing Claude terminal exists
   - Clean up buffer on terminal exit
   - Register cleanup callback via `TermClose` autocmd
5. **Server Not Started Handling**
   - Display error message if the server has not started yet
   - Display guidance message if `setup()` has not been called

## Acceptance Criteria

- [x] `:ClaudeCode` execution opens a vsplit terminal
- [x] Claude CLI runs in the terminal
- [x] `CLAUDE_CODE_SSE_PORT` environment variable set to correct port
- [x] `MCP_CONNECTION_NONBLOCKING` environment variable set to `"true"`
- [x] Claude CLI reads environment variables and finds lock file to attempt WebSocket connection
- [x] Focus switches to existing Claude terminal if one exists
- [x] Buffer cleaned up on terminal exit

## Reference Specs

- `specs/07-plugin-api.md` section 7.2 (user commands: :ClaudeCode)
- `specs/02-connection.md` section 2.4 (ENV-01: CLAUDE_CODE_SSE_PORT, ENV-02: MCP_CONNECTION_NONBLOCKING)
- `specs/02-connection.md` section 2.5 (full connection sequence, step 6)

## Estimated Time: ~2 hours
