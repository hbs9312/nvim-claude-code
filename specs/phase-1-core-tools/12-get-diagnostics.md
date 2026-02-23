# Phase 1-12: getDiagnostics Tool (LSP Diagnostics)

## Status: ✅ Complete

## Purpose

Expose Neovim LSP diagnostic information as a public MCP tool (`mcp__ide__getDiagnostics`). This enables Claude to recognize errors/warnings in the current file or across the entire workspace and propose fixes. This is Cluster D and can be executed independently.

## Dependencies

- [x] Phase 0: Foundation Infrastructure (complete)
- [ ] Phase 1-01: Tool Registration System (required, incomplete)

> Note: Cluster D — can proceed independently of other Phase 1 subtasks

## Input

```json
{ "uri": "file:///path/to/file.lua" }
```

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `uri` | string | N | File URI. If omitted, returns diagnostics for all files |

## Output

```json
{
  "content": [{
    "type": "text",
    "text": "[{\"uri\": \"file:///path/to/file.lua\", \"diagnostics\": [{\"message\": \"Unused variable 'x'\", \"severity\": \"Warning\", \"range\": {\"start\": {\"line\": 5, \"character\": 10}, \"end\": {\"line\": 5, \"character\": 11}}, \"source\": \"lua_ls\"}]}]"
  }]
}
```

Diagnostic item structure:

| Field | Type | Description |
|-------|------|-------------|
| `message` | string | Diagnostic message |
| `severity` | string | "Error", "Warning", "Information", "Hint" |
| `range.start` | object | Start position {line, character} (0-indexed) |
| `range.end` | object | End position {line, character} (0-indexed) |
| `source` | string | Diagnostic source (e.g., "lua_ls", "pyright") |

## Implementation Plan

### File: `lua/claude-code/tools/diagnostics.lua`

1. **Tool registration**
   ```lua
   tools.register("getDiagnostics", {
     description = "Get diagnostics (errors, warnings) for files in the workspace",
     inputSchema = {
       type = "object",
       properties = {
         uri = {
           type = "string",
           description = "File URI (e.g., file:///path/to/file). If omitted, returns all diagnostics.",
         },
       },
     },
     handler = function(args)
       return M.get_diagnostics(args.uri)
     end,
   })
   ```

2. **Severity mapping**
   ```lua
   local severity_map = {
     [vim.diagnostic.severity.ERROR] = "Error",
     [vim.diagnostic.severity.WARN] = "Warning",
     [vim.diagnostic.severity.INFO] = "Information",
     [vim.diagnostic.severity.HINT] = "Hint",
   }
   ```

3. **Get diagnostics for a specific file**
   ```lua
   local function get_file_diagnostics(uri)
     -- Convert file:// URI to file path
     local filepath = vim.uri_to_fname(uri)
     local bufnr = vim.fn.bufnr(filepath)

     if bufnr == -1 then
       return { uri = uri, diagnostics = {} }
     end

     local diags = vim.diagnostic.get(bufnr)
     local result = {}

     for _, d in ipairs(diags) do
       table.insert(result, {
         message = d.message,
         severity = severity_map[d.severity] or "Information",
         range = {
           start = { line = d.lnum, character = d.col },
           ["end"] = { line = d.end_lnum or d.lnum, character = d.end_col or d.col },
         },
         source = d.source or "",
       })
     end

     return { uri = uri, diagnostics = result }
   end
   ```

4. **Get diagnostics for all files**
   ```lua
   local function get_all_diagnostics()
     local results = {}

     -- Iterate over all open buffers
     for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
       if vim.api.nvim_buf_is_loaded(bufnr) then
         local filepath = vim.api.nvim_buf_get_name(bufnr)
         if filepath ~= "" then
           local uri = vim.uri_from_fname(filepath)
           local file_diags = get_file_diagnostics(uri)
           if #file_diags.diagnostics > 0 then
             table.insert(results, file_diags)
           end
         end
       end
     end

     return results
   end
   ```

5. **Handler**
   ```lua
   function M.get_diagnostics(uri)
     local results
     if uri then
       results = { get_file_diagnostics(uri) }
     else
       results = get_all_diagnostics()
     end

     return {
       content = {{
         type = "text",
         text = vim.json.encode(results),
       }},
     }
   end
   ```

## Acceptance Criteria

- [ ] Specifying the URI of a file with LSP diagnostics → returns diagnostics for that file
- [ ] URI omitted → returns diagnostics for all open files
- [ ] File with no diagnostics → empty diagnostics array
- [ ] Severity mapping: 1→Error, 2→Warning, 3→Information, 4→Hint
- [ ] range is 0-indexed (vim.diagnostic.get() is already 0-indexed)
- [ ] source field contains the LSP server name

## Reference Specs

- [04-tools.md](../04-tools.md) Section 4.6 — getDiagnostics

## Estimated Time: ~1.5 hours
