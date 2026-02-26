local M = {}

M.defaults = {
  server = {
    host = "127.0.0.1",
    port_range = { 10000, 65535 },
  },
  auto_start = true,
  log = {
    level = "warn", -- "debug", "info", "warn", "error"
  },
  terminal = {
    mode = "vsplit", -- "vsplit" | "external"
    split_side = "right",
    split_width_percentage = 0.3,
  },
  diagnostics = {
    enabled = true, -- send diagnostics_changed notifications
  },
  diff = {
    auto_close = true,
    feedback_delay = 800, -- ms, 0 to close immediately
    keymaps = {
      accept = { "<CR>", "ga" },
      reject = { "q", "gx" },
    },
  },
  plan = {
    enabled = true,
    keymaps = {
      comment = "gc",
      general_comment = "gC",
      submit = "<leader>ps",
      accept = "<leader>pa",
      clear = "<leader>px",
      close = "q",
    },
  },
}

--- @type table
M.values = {}

--- Apply user options over defaults
--- @param user_opts table|nil
--- @return table
function M.apply(user_opts)
  M.values = vim.tbl_deep_extend("force", M.defaults, user_opts or {})

  -- Validate
  local host = M.values.server.host
  assert(host == "127.0.0.1" or host == "localhost", "server.host must be 127.0.0.1 or localhost")

  local range = M.values.server.port_range
  assert(type(range) == "table" and #range == 2, "server.port_range must be {min, max}")
  assert(range[1] >= 1024 and range[2] <= 65535, "port_range must be within 1024-65535")

  local valid_levels = { debug = true, info = true, warn = true, error = true }
  assert(valid_levels[M.values.log.level], "log.level must be debug/info/warn/error")

  local valid_modes = { vsplit = true, external = true }
  assert(valid_modes[M.values.terminal.mode], "terminal.mode must be 'vsplit' or 'external'")

  return M.values
end

return M


