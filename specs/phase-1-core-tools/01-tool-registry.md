# Phase 1-01: Tool Registration System

## Status: ✅ Complete

## Purpose

Implement a central registry system that manages tool registration, lookup, and execution. It connects to the MCP protocol's `tools/list` and `tools/call` methods, enabling the Claude CLI to discover and invoke available tools.

## Dependencies

- [x] Phase 0: Foundation Infrastructure (complete)
  - WebSocket server, MCP protocol handler, JSON-RPC routing

## Input

Tool definition:

```lua
{
  name = "openFile",                    -- Tool name (unique)
  description = "Open a file in ...",   -- Tool description
  inputSchema = {                       -- JSON Schema
    type = "object",
    properties = { ... },
    required = { ... },
  },
  handler = function(args, callback)    -- Execution handler
    -- args: tool parameters
    -- callback: async response (for blocking tools)
  end,
  annotations = {                       -- MCP annotations (optional)
    title = "Open File",
    readOnlyHint = true,
    openWorldHint = false,
  },
}
```

## Output

- `tools/list` response: list of registered tools (name, description, inputSchema, annotations)
- `tools/call` response: tool execution result `{content: [{type: "text", text: "..."}]}`

## Implementation Plan

### File: `lua/claude-code/tools/init.lua`

1. **Registry table**
   - `M._tools = {}` — a map of tool definitions keyed by name

2. **register(name, definition)**
   - Check for duplicate tool names
   - Store definition in the registry
   - Validate required fields: name, description, inputSchema, handler

3. **list()**
   - Convert all registered tools to MCP format and return
   - `{tools: [{name, description, inputSchema, annotations?}, ...]}`

4. **call(name, args)**
   - Look up tool by name
   - Unregistered tool → return MCP error code -32601
   - Invoke tool handler (within vim.schedule)
   - Blocking tool: callback pattern (response is held until handler invokes callback)
   - Non-blocking tool: respond immediately with handler return value

5. **MCP handler wiring**
   - `tools/list` request → call `list()`
   - `tools/call` request → call `call(params.name, params.arguments)`

## Acceptance Criteria

- [ ] After registration, the tool appears in the `tools/list` response
- [ ] Registered tools can be executed via `tools/call`
- [ ] Calling an unregistered tool returns an appropriate error response (-32601)
- [ ] Tools without a description are excluded from `tools/list` (hidden tools like close_tab)
- [ ] Blocking tool callback pattern works correctly
- [ ] Tools with annotations include those annotations in the `tools/list` response

## Reference Specs

- [03-mcp-protocol.md](../03-mcp-protocol.md) Section 3.4 — tools/list, tools/call methods
- [04-tools.md](../04-tools.md) Section 4.1 — Tool list and priorities

## Estimated Time: ~2 hours
