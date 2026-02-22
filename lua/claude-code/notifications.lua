--- Outgoing notifications (Neovim → Claude CLI)
--- Manages at_mentioned and diagnostics_changed notifications.

local server = require("claude-code.server")
local config = require("claude-code.config")

local M = {}

--- Send at_mentioned notification for current file/selection
--- @param opts table|nil Command opts with range info, or nil for Lua API usage
--- @param filepath string|nil Override file path (for Lua API)
--- @param startline number|nil 0-indexed start line (for Lua API)
--- @param endline number|nil 0-indexed end line (for Lua API)
function M.at_mention(opts, filepath, startline, endline)
  filepath = filepath or vim.api.nvim_buf_get_name(0)
  if filepath == "" then
    vim.notify("[claude-code] No file to mention", vim.log.levels.WARN)
    return
  end

  local params = { filePath = filepath }

  -- Check for Lua API direct line args first
  if startline and endline then
    params.lineStart = startline -- already 0-indexed
    params.lineEnd = endline
  elseif opts and opts.range == 2 then
    -- Command with Visual range: convert 1-indexed to 0-indexed
    params.lineStart = opts.line1 - 1
    params.lineEnd = opts.line2 - 1
  end

  server.send_notification("at_mentioned", params)
  vim.notify(
    "[claude-code] Mentioned: " .. vim.fn.fnamemodify(filepath, ":t"),
    vim.log.levels.INFO
  )
end

--- @type number|nil autocmd group id for diagnostics
local diag_augroup = nil

--- Setup DiagnosticChanged autocmd to send diagnostics_changed notifications
function M.setup_diagnostics()
  if not config.values.diagnostics or not config.values.diagnostics.enabled then
    return
  end

  diag_augroup = vim.api.nvim_create_augroup("ClaudeCodeDiagnostics", { clear = true })
  vim.api.nvim_create_autocmd("DiagnosticChanged", {
    group = diag_augroup,
    callback = function(args)
      if not server.is_client_connected() then
        return
      end

      local bufnr = args.buf
      if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end

      local name = vim.api.nvim_buf_get_name(bufnr)
      if name == "" then
        return
      end

      server.send_notification("diagnostics_changed", {
        uris = { vim.uri_from_bufnr(bufnr) },
      })
    end,
  })
end

--- Teardown DiagnosticChanged autocmd
function M.teardown_diagnostics()
  if diag_augroup then
    vim.api.nvim_del_augroup_by_id(diag_augroup)
    diag_augroup = nil
  end
end

return M
