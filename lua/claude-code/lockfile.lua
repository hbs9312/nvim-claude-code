local util = require("claude-code.util")

local uv = vim.uv or vim.loop
local M = {}

--- Get the IDE lock directory path
--- @return string
local function get_lock_dir()
  local config_dir = os.getenv("CLAUDE_CONFIG_DIR") or (os.getenv("HOME") .. "/.claude")
  return config_dir .. "/ide"
end

--- Collect workspace folders (cwd + LSP workspace folders, deduplicated)
--- @return string[]
local function collect_workspace_folders()
  local cwd = vim.fn.getcwd()
  local folders = { cwd }
  local seen = { [cwd] = true }

  -- Try to add LSP workspace folders if available
  local ok, lsp_folders = pcall(vim.lsp.buf.list_workspace_folders)
  if ok and lsp_folders and #lsp_folders > 0 then
    for _, folder_path in ipairs(lsp_folders) do
      if not seen[folder_path] then
        seen[folder_path] = true
        folders[#folders + 1] = folder_path
      end
    end
  end

  return folders
end

--- Create the lock file for the given port
--- @param port number
--- @param auth_token string
function M.create(port, auth_token)
  local lock_dir = get_lock_dir()

  -- Ensure directory exists with 0700
  local stat = uv.fs_stat(lock_dir)
  if not stat then
    -- Create parent dir if needed
    local parent = lock_dir:match("^(.+)/[^/]+$")
    if parent then
      local pstat = uv.fs_stat(parent)
      if not pstat then
        uv.fs_mkdir(parent, 448) -- 0o700
      end
    end
    uv.fs_mkdir(lock_dir, 448) -- 0o700
  end

  local lock_path = lock_dir .. "/" .. port .. ".lock"
  local data = vim.json.encode({
    pid = vim.fn.getpid(),
    workspaceFolders = collect_workspace_folders(),
    ideName = "Neovim",
    transport = "ws",
    useWebSocket = true,
    runningInWindows = vim.fn.has("win32") == 1,
    authToken = auth_token,
  })

  -- Write via temp file + rename for atomicity
  local tmp_path = lock_path .. ".tmp"
  local fd = uv.fs_open(tmp_path, "w", 384) -- 0o600
  if not fd then
    util.log_error("Failed to create lock file: %s", tmp_path)
    return
  end
  uv.fs_write(fd, data, 0)
  uv.fs_close(fd)
  uv.fs_rename(tmp_path, lock_path)

  util.log_info("Lock file created: %s", lock_path)
end

--- Remove the lock file for the given port
--- @param port number
function M.remove(port)
  local lock_path = get_lock_dir() .. "/" .. port .. ".lock"
  local stat = uv.fs_stat(lock_path)
  if stat then
    uv.fs_unlink(lock_path)
    util.log_info("Lock file removed: %s", lock_path)
  end
end

return M
