--- getDiagnostics tool — Get LSP diagnostics for a file or all open files
--- MCP public tool: mcp__ide__getDiagnostics
local tools = require("claude-code.tools")

--- Severity number to string mapping
--- vim.diagnostic.severity: ERROR=1, WARN=2, INFO=3, HINT=4
local severity_map = {
  [vim.diagnostic.severity.ERROR] = "Error",
  [vim.diagnostic.severity.WARN] = "Warning",
  [vim.diagnostic.severity.INFO] = "Information",
  [vim.diagnostic.severity.HINT] = "Hint",
}

--- Convert a file URI to a buffer number
--- @param uri string file URI (e.g., "file:///path/to/file.lua")
--- @return number bufnr buffer number, or -1 if not found/loaded
local function uri_to_bufnr(uri)
  local filepath = vim.uri_to_fname(uri)
  return vim.fn.bufnr(filepath)
end

--- Get diagnostics for a single buffer and return them in MCP format
--- @param bufnr number buffer handle
--- @param uri string file URI
--- @return table result { uri = string, diagnostics = table[] }
local function get_buf_diagnostics(bufnr, uri)
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

--- Get diagnostics for a specific file URI
--- @param uri string file URI
--- @return table[] results array with single entry
local function get_file_diagnostics(uri)
  local bufnr = uri_to_bufnr(uri)
  if bufnr == -1 then
    return { { uri = uri, diagnostics = {} } }
  end
  return { get_buf_diagnostics(bufnr, uri) }
end

--- Get diagnostics for all loaded buffers
--- @return table[] results array of { uri, diagnostics } entries (only non-empty)
local function get_all_diagnostics()
  local results = {}

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local filepath = vim.api.nvim_buf_get_name(bufnr)
      if filepath ~= "" then
        local uri = vim.uri_from_fname(filepath)
        local entry = get_buf_diagnostics(bufnr, uri)
        if #entry.diagnostics > 0 then
          table.insert(results, entry)
        end
      end
    end
  end

  return results
end

--- Handler for the getDiagnostics tool
--- @param params table tool parameters
--- @return table MCP content response
local function handler(params)
  local results
  if params.uri and params.uri ~= "" then
    results = get_file_diagnostics(params.uri)
  else
    results = get_all_diagnostics()
  end

  return {
    content = { {
      type = "text",
      text = vim.json.encode(results),
    } },
  }
end

-- Register the tool
tools.register({
  name = "getDiagnostics",
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
  handler = handler,
})
