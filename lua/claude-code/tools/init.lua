--- Tool registry for MCP tools
--- Manages registration, listing, and dispatching of all tools.

local util = require("claude-code.util")

local M = {}

--- @class ToolDefinition
--- @field name string
--- @field description string
--- @field inputSchema table
--- @field handler fun(params: table, id: string|number|nil): table|nil
--- @field annotations table|nil

--- @type table<string, ToolDefinition>
local registry = {}

--- Register a tool (idempotent — skips if already registered)
--- @param def ToolDefinition
function M.register(def)
  assert(def.name, "Tool must have a name")
  assert(def.handler, "Tool must have a handler")
  if registry[def.name] then
    return
  end
  registry[def.name] = def
  util.log_debug("Tool registered: %s", def.name)
end

--- Get list of all registered tools (for tools/list response)
--- @return table[]
function M.list()
  local tools = {}
  for _, def in pairs(registry) do
    local tool = {
      name = def.name,
      inputSchema = def.inputSchema or { type = "object", properties = vim.empty_dict() },
    }
    -- Only include description if it's non-empty (close_tab has empty description)
    if def.description and def.description ~= "" then
      tool.description = def.description
    end
    if def.annotations then
      tool.annotations = def.annotations
    end
    tools[#tools + 1] = tool
  end
  return tools
end

--- Call a tool by name
--- @param name string
--- @param arguments table
--- @param id string|number|nil JSON-RPC request id (for deferred/blocking tools)
--- @return table|nil result MCP content response, or nil if deferred
function M.call(name, arguments, id)
  local def = registry[name]
  if not def then
    error("Unknown tool: " .. tostring(name))
  end
  return def.handler(arguments or {}, id)
end

--- Get number of registered tools
--- @return number
function M.count()
  local n = 0
  for _ in pairs(registry) do
    n = n + 1
  end
  return n
end

--- Check if a tool is registered
--- @param name string
--- @return boolean
function M.has(name)
  return registry[name] ~= nil
end

--- Clear all registered tools (for testing)
function M.clear()
  registry = {}
end

return M
