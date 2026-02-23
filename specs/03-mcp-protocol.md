# 03. MCP Protocol

## 3.1 Protocol Foundation

- Based on **JSON-RPC 2.0**
- Compliant with the **MCP (Model Context Protocol)** spec
- Supported protocol version: `2025-03-26` (minimum)

## 3.2 MCP Initialization

### Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| MCP-01 | Respond to `initialize` request with server capabilities | Required |
| MCP-02 | Handle `initialized` notification receipt | Required |
| MCP-03 | Respond to `tools/list` request with registered tool list | Required |
| MCP-04 | Execute tool and respond with result for `tools/call` request | Required |
| MCP-05 | MCP server name: `"Claude Code Neovim MCP"` | Recommended |

### Initialization Sequence

```
Claude CLI (Client)                  Neovim (Server)
    │                                    │
    │──── initialize ───────────────────►│
    │     {protocolVersion, capabilities, │
    │      clientInfo}                    │
    │◄─── result ───────────────────────│
    │     {protocolVersion, capabilities, │
    │      serverInfo}                    │
    │──── notifications/initialized ────►│
    │                                    │
    │──── tools/list ──────────────────►│
    │◄─── {tools: [...]} ──────────────│
    │                                    │
    │──── tools/call ─────────────────►│
    │     {name, arguments}              │
    │◄─── {content: [...]} ────────────│
    │                                    │
```

### initialize Response Example

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

## 3.3 Message Structure

### Request

```json
{
  "jsonrpc": "2.0",
  "id": "unique-id",
  "method": "method_name",
  "params": {}
}
```

### Response

```json
{
  "jsonrpc": "2.0",
  "id": "unique-id",
  "result": {}
}
```

### Error Response

```json
{
  "jsonrpc": "2.0",
  "id": "unique-id",
  "error": {
    "code": -32601,
    "message": "Method not found"
  }
}
```

### Notification — no id

```json
{
  "jsonrpc": "2.0",
  "method": "method_name",
  "params": {}
}
```

## 3.4 MCP Methods to Support

### Standard Methods

| Method | Direction | Type | Priority |
|--------|-----------|------|----------|
| `initialize` | CLI→Neovim | request | Required |
| `notifications/initialized` | CLI→Neovim | notification | Required |
| `tools/list` | CLI→Neovim | request | Required |
| `tools/call` | CLI→Neovim | request | Required |
| `notifications/cancelled` | CLI→Neovim | notification | Recommended |

### Custom Methods (Neovim → CLI)

| Method | Type | Priority | Description |
|--------|------|----------|-------------|
| `selection_changed` | notification | Required | Editor selection change notification |
| `at_mentioned` | notification | Recommended | Send @mention context |
| `diagnostics_changed` | notification | Recommended | LSP diagnostics change notification |
| `log_event` | notification | Optional | Event logging |

## 3.5 Error Codes

| Code | Meaning | Usage |
|------|---------|-------|
| `-32700` | Parse error | JSON parsing failure |
| `-32600` | Invalid request | Invalid JSON-RPC |
| `-32601` | Method not found | Unsupported method |
| `-32602` | Invalid params | Invalid parameters |
| `-32603` | Internal error | Internal error |
