local config = require("claude-code.config")
local util = require("claude-code.util")
local lockfile = require("claude-code.lockfile")
local server = require("claude-code.server")
local mcp = require("claude-code.mcp")

local M = {}

--- @type string|nil Current auth token
local auth_token = nil

--- @type number|nil Current autocmd group id
local augroup = nil

--- @type number|nil Terminal buffer number
local term_bufnr = nil

--- Start the MCP server and create the lock file
function M.start()
  if server.is_running() then
    util.log_warn("Already running on port %d", server.get_port() or 0)
    return
  end

  auth_token = util.generate_uuid()

  -- Register default MCP handlers
  mcp.register_defaults()

  local port = server.start(config.values, auth_token)
  if not port then
    util.log_error("Failed to start server")
    return
  end

  lockfile.create(port, auth_token)
  util.log_info("Claude Code server ready on port %d", port)
end

--- Stop the server and clean up
function M.stop()
  local port = server.get_port()
  if port then
    lockfile.remove(port)
  end
  server.stop()
  auth_token = nil
  util.log_info("Claude Code server stopped")
end

--- Check if the server is running
--- @return boolean
function M.is_running()
  return server.is_running()
end

--- Get the current server port
--- @return number|nil
function M.get_port()
  return server.get_port()
end

--- Parse mode and remaining args from command arguments
--- @param args string|nil
--- @return string mode, string rest
local function parse_mode_from_args(args)
  if not args or args == "" then
    return config.values.terminal.mode, ""
  end
  local first = args:match("^(%S+)")
  if first == "vsplit" or first == "external" then
    local rest = args:sub(#first + 1):match("^%s*(.*)")
    return first, rest or ""
  end
  return config.values.terminal.mode, args
end

--- Ensure server is running, return true if ready
--- @return boolean
local function ensure_server()
  if not server.is_running() then
    util.log_warn("Server not running, starting first...")
    M.start()
    if not server.is_running() then
      return false
    end
  end
  return true
end

--- Check for existing client connection and ask user before proceeding.
--- Calls callback() if no client connected or user confirms disconnect.
--- @param callback function
local function check_existing_client(callback)
  if not server.is_client_connected() then
    callback()
    return
  end

  vim.ui.select({ "Yes", "No" }, {
    prompt = "[claude-code] A client is already connected. Disconnect and continue?",
  }, function(choice)
    if choice == "Yes" then
      server.disconnect_client()
      callback()
    end
  end)
end

--- Open Claude CLI in a terminal split (internal implementation)
--- @param args string|nil additional CLI arguments
local function do_open_vsplit(args)
  -- If terminal buffer exists and is valid, focus it
  if term_bufnr and vim.api.nvim_buf_is_valid(term_bufnr) then
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == term_bufnr then
        vim.api.nvim_set_current_win(win)
        return
      end
    end
  end

  local port = server.get_port()

  -- Build shell command with env vars prepended
  local env_cmd = string.format(
    "unset CLAUDECODE && CLAUDE_CODE_SSE_PORT=%d MCP_CONNECTION_NONBLOCKING=true claude --ide",
    port
  )
  if args and args ~= "" then
    env_cmd = env_cmd .. " " .. args
  end

  -- Open vertical split on the configured side
  local split_side = config.values.terminal.split_side
  local width = math.floor(vim.o.columns * config.values.terminal.split_width_percentage)

  if split_side == "left" then
    vim.cmd("topleft " .. width .. "vnew")
  else
    vim.cmd("botright " .. width .. "vnew")
  end

  -- Start terminal in the new buffer
  vim.fn.termopen(env_cmd, {
    on_exit = function()
      term_bufnr = nil
    end,
  })
  term_bufnr = vim.api.nvim_get_current_buf()
  vim.cmd("startinsert")
end

--- Open Claude CLI in a terminal split
--- @param args string|nil additional CLI arguments
function M.open_vsplit(args)
  if not ensure_server() then return end
  check_existing_client(function()
    do_open_vsplit(args)
  end)
end

--- Start server and show command for external terminal usage (internal implementation)
local function do_open_external()
  local port = server.get_port()
  local cmd = string.format(
    "unset CLAUDECODE && CLAUDE_CODE_SSE_PORT=%d MCP_CONNECTION_NONBLOCKING=true claude --ide",
    port
  )

  vim.fn.setreg("+", cmd)
  vim.notify(string.format(
    "[claude-code] Server ready on port %d\nRun in your terminal:\n  %s\n(Copied to clipboard)",
    port, cmd
  ), vim.log.levels.INFO)
end

--- Start server and show command for external terminal usage
function M.open_external()
  if not ensure_server() then return end
  check_existing_client(function()
    do_open_external()
  end)
end

--- Open Claude CLI based on mode
--- @param args string|nil command arguments (optional mode prefix + CLI args)
function M.open_terminal(args)
  local mode, rest = parse_mode_from_args(args)
  if mode == "external" then
    M.open_external()
  else
    M.open_vsplit(rest)
  end
end

--- Show connection status
function M.status()
  if not server.is_running() then
    print("[claude-code] Server not running")
    return
  end

  local port = server.get_port()
  local connected = server.is_client_connected()
  print(string.format(
    "[claude-code] Server: port %d | Client: %s",
    port or 0,
    connected and "connected" or "not connected"
  ))
end

--- Setup the plugin
--- @param opts table|nil
function M.setup(opts)
  config.apply(opts)
  util.set_log_level(config.values.log.level)

  -- Create commands
  vim.api.nvim_create_user_command("ClaudeCode", function(cmd_opts)
    M.open_terminal(cmd_opts.args)
  end, {
    nargs = "*",
    complete = function() return { "vsplit", "external" } end,
    desc = "Open Claude Code CLI in a terminal",
  })

  vim.api.nvim_create_user_command("ClaudeCodeStatus", function()
    M.status()
  end, { desc = "Show Claude Code connection status" })

  vim.api.nvim_create_user_command("ClaudeCodeStart", function()
    M.start()
  end, { desc = "Start Claude Code server" })

  vim.api.nvim_create_user_command("ClaudeCodeStop", function()
    M.stop()
  end, { desc = "Stop Claude Code server" })

  -- Cleanup on exit
  augroup = vim.api.nvim_create_augroup("ClaudeCode", { clear = true })
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = augroup,
    callback = function()
      M.stop()
    end,
  })

  -- Auto-start if configured
  if config.values.auto_start then
    M.start()
  end
end

return M
