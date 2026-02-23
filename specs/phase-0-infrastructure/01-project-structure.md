# Phase 0-01: Project Directory Structure, Module Skeleton

## Status: Completed

## Purpose

Create the `lua/claude-code/` directory structure and module skeletons. Establish the basic structure so that each module file can be properly `require`d, and define the dependency direction between modules.

## Dependencies

- None (first task)

## Input

- None

## Output

- Create the following module files under `lua/claude-code/`:
  - `init.lua` -- entry point, setup() function, public API
  - `config.lua` -- default config definition and merge logic
  - `server.lua` -- TCP server management
  - `websocket.lua` -- WebSocket protocol handling
  - `mcp.lua` -- MCP/JSON-RPC protocol handling
  - `lockfile.lua` -- Lock file creation/deletion
  - `util.lua` -- utility functions (UUID, logging, SHA-1, Base64, etc.)

## Implementation Plan

1. Create `lua/claude-code/` directory (skip if already exists)
2. Write a skeleton for each module file that returns an empty table:
   ```lua
   local M = {}
   -- function stub definitions
   return M
   ```
3. Verify `init.lua` `require`s the other modules
4. Confirm `require("claude-code")` loads without errors in Neovim

## Acceptance Criteria

- [x] 7 module files exist in the `lua/claude-code/` directory
- [x] `require("claude-code")` loads without errors
- [x] Each module can be independently `require`d
- [x] No circular dependencies between modules

## Reference Specs

- `specs/07-plugin-api.md` section 7.6 (module structure)

## Estimated Time: ~1 hour
