# Phase 0-05: Lock File Creation/Deletion, Atomic Write

## Status: Completed

## Purpose

Manage the `~/.claude/ide/{port}.lock` file. This allows Claude CLI to read the file and find the WebSocket server's connection information (port, authentication token, etc.). File permissions are set strictly, and atomic writes ensure consistency.

## Dependencies

- 02-tcp-server (completed) -- Bound port number required

## Input

- `port`: WebSocket server port number
- `pid`: Neovim process PID (`vim.fn.getpid()`)
- `authToken`: UUID v4 authentication token
- `workspaceFolders`: List of current working directories (based on `vim.fn.getcwd()`)

## Output

- Lock file: `~/.claude/ide/{port}.lock` (permissions `0o600`)
- Lock file JSON contents:
  ```json
  {
    "pid": 12345,
    "workspaceFolders": ["/path/to/project"],
    "ideName": "Neovim",
    "transport": "ws",
    "runningInWindows": false,
    "authToken": "550e8400-e29b-41d4-a716-446655440000"
  }
  ```
- Automatic lock file deletion via `VimLeavePre` autocmd

## Implementation Plan

1. Implement `M.create(port, auth_token)` function in `lockfile.lua`
2. Check/create directory
   - Verify `~/.claude/ide/` path
   - If missing, create with `vim.fn.mkdir(path, "p")` and `vim.uv.fs_chmod(path, 448)` (0o700)
3. Compose lock file contents
   - `pid`: `vim.fn.getpid()`
   - `workspaceFolders`: `{ vim.fn.getcwd() }`
   - `ideName`: `"Neovim"` (fixed)
   - `transport`: `"ws"` (fixed)
   - `runningInWindows`: `vim.fn.has("win32") == 1`
   - `authToken`: UUID v4 string passed as argument
4. Atomic write (LCK-05)
   - Write JSON to a temporary file (`{port}.lock.tmp`)
   - Atomically replace with `vim.uv.fs_rename()`
5. Set file permissions
   - `vim.uv.fs_chmod(filepath, 384)` (0o600)
6. Implement `M.remove(port)` function
   - Delete file with `vim.uv.fs_unlink()`
   - Ignore if file does not exist
7. Register `VimLeavePre` autocmd
   - Call `M.remove()` on exit

## Acceptance Criteria

- [x] `~/.claude/ide/` directory auto-created (permissions 0o700)
- [x] Lock file created with correct JSON contents
- [x] Lock file permissions set to 0o600
- [x] Atomic write (temporary file -> rename)
- [x] Lock file deleted on `VimLeavePre`
- [x] No error when calling remove on an already deleted file

## Reference Specs

- `specs/02-connection.md` section 2.2 (LCK-01 ~ LCK-05)
- `specs/02-connection.md` section 2.5 (full connection sequence, steps 4~5)
- `specs/02-connection.md` section 2.6 (CLN-01: lock file deletion)

## Estimated Time: ~1 hour
