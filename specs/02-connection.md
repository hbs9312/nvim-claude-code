# 02. Connection and Authentication

## 2.1 WebSocket Server

### Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| CON-01 | Bind only to localhost (127.0.0.1) | Required |
| CON-02 | Port: auto-select an available port in the range 10000~65535 | Required |
| CON-03 | Comply with RFC 6455 WebSocket protocol | Required |
| CON-04 | Single client policy: close previous connection when a new one arrives | Required |
| CON-05 | Implement WebSocket on top of a `vim.uv` (libuv) based TCP server | Recommended |

### Implementation Details

```
Neovim starts
  → Plugin loads
  → Create TCP server (vim.uv.new_tcp())
  → Handle WebSocket Upgrade handshake
  → Receive/send JSON-RPC messages
```

## 2.2 Lock File

### Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| LCK-01 | Path: `~/.claude/ide/{port}.lock` | Required |
| LCK-02 | Create directory `~/.claude/ide/` if it doesn't exist (permissions `0o700`) | Required |
| LCK-03 | File permissions `0o600` | Required |
| LCK-04 | Delete lock file on Neovim exit (`VimLeavePre`) | Required |
| LCK-05 | Atomic write for lock file (temp file → rename) | Recommended |

### Lock File Structure

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

| Field | Type | Value | Description |
|-------|------|-------|-------------|
| `pid` | number | `vim.fn.getpid()` | Neovim process PID |
| `workspaceFolders` | string[] | Current working directory | Based on `vim.fn.getcwd()` |
| `ideName` | string | `"Neovim"` | Fixed |
| `transport` | string | `"ws"` | Fixed |
| `runningInWindows` | boolean | `vim.fn.has("win32") == 1` | OS detection |
| `authToken` | string | Randomly generated UUID v4 | Authentication token |

## 2.3 Authentication

### Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| AUTH-01 | Validate `x-claude-code-ide-authorization` header on WebSocket connection | Required |
| AUTH-02 | Reject connection (close 1008) if header value doesn't match lock file's `authToken` | Required |
| AUTH-03 | Generate a new authToken for each session | Required |

### Authentication Flow

```
1. Neovim generates authToken (UUID v4)
2. Writes authToken to lock file
3. Claude CLI reads authToken from lock file
4. Includes it in x-claude-code-ide-authorization header on WebSocket connection
5. Neovim validates the header value
6. On mismatch → WebSocket close(1008, "Unauthorized")
```

## 2.4 Environment Variables

Environment variables to set when launching Claude CLI:

| ID | Environment Variable | Value | Priority | Notes |
|----|---------------------|-------|----------|-------|
| ENV-01 | `CLAUDE_CODE_SSE_PORT` | WebSocket server port | Required | |
| ENV-02 | `MCP_CONNECTION_NONBLOCKING` | `"true"` | Recommended | Confirmed in use by VS Code extension |

> Note: `ENABLE_IDE_INTEGRATION` is not used in the VS Code extension code. Needs verification whether it's handled internally by the CLI.

## 2.5 Full Connection Sequence

```
1. Neovim plugin loads (setup() called)
2. Generate UUID v4 authToken
3. Create TCP server (localhost:random_port)
4. Check/create ~/.claude/ide/ directory (0o700)
5. Write lock file (0o600)
6. (User launches Claude CLI — or plugin launches it in terminal)
7. Claude CLI reads lock file and establishes WebSocket connection
8. Validate x-claude-code-ide-authorization header
9. MCP initialize handshake
10. Bidirectional communication begins
```

## 2.6 Shutdown Handling

| ID | Requirement | Priority |
|----|-------------|----------|
| CLN-01 | Delete lock file in `VimLeavePre` autocmd | Required |
| CLN-02 | Graceful WebSocket connection close (send close frame) | Required |
| CLN-03 | Close TCP server | Required |
| CLN-04 | Clean up all resources (timers, event handlers, etc.) | Required |
