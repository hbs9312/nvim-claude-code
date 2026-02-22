--- openDiff tool — Show a diff between original and proposed changes
--- This is a blocking (deferred) tool: the MCP response is sent when the user
--- accepts or rejects the diff, not when the handler returns.

local util = require("claude-code.util")
local tools = require("claude-code.tools")
local mcp = require("claude-code.mcp")
local diff = require("claude-code.diff")

--- Handler for the openDiff tool
--- @param params table tool parameters
--- @param id string|number|nil JSON-RPC request id (needed for deferred response)
--- @return nil always nil — response is deferred
local function handler(params, id)
  local old_file_path = params.old_file_path
  local new_file_path = params.new_file_path
  local new_file_contents = params.new_file_contents

  -- Validate required parameters
  if not old_file_path or old_file_path == "" then
    -- Return error synchronously (not deferred)
    return {
      content = { { type = "text", text = "Error: old_file_path is required" } },
      isError = true,
    }
  end
  if not new_file_path or new_file_path == "" then
    return {
      content = { { type = "text", text = "Error: new_file_path is required" } },
      isError = true,
    }
  end
  if new_file_contents == nil then
    return {
      content = { { type = "text", text = "Error: new_file_contents is required" } },
      isError = true,
    }
  end

  if not id then
    util.log_error("openDiff: no request id — cannot defer response")
    return {
      content = { { type = "text", text = "Error: internal error (no request id)" } },
      isError = true,
    }
  end

  -- Use mcp.defer_response to set up the deferred callback, then show the diff UI
  mcp.defer_response(id, function(send)
    diff.show({
      old_file_path = old_file_path,
      new_file_path = new_file_path,
      new_file_contents = new_file_contents,
      tab_name = params.tab_name or "",
    }, send)
  end)

  -- Return nil to signal that the response is deferred
  return nil
end

-- Register the tool
tools.register({
  name = "openDiff",
  description = "Shows a diff between the original and the proposed file content in a side-by-side view. "
    .. "The user can accept or reject the changes. Blocks until the user makes a decision.",
  inputSchema = {
    type = "object",
    properties = {
      old_file_path = {
        type = "string",
        description = "The path of the original file",
      },
      new_file_path = {
        type = "string",
        description = "The path where the modified file will be saved",
      },
      new_file_contents = {
        type = "string",
        description = "The full content of the modified file",
      },
      tab_name = {
        type = "string",
        description = "Display name for the diff tab (optional)",
      },
    },
    required = { "old_file_path", "new_file_path", "new_file_contents" },
  },
  annotations = {
    title = "Review Diff",
    readOnlyHint = false,
    destructiveHint = false,
    idempotentHint = false,
    openWorldHint = false,
  },
  handler = handler,
})
