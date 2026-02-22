--- Editor information tools — getOpenEditors + getWorkspaceFolders
local tools = require("claude-code.tools")

--------------------------------------------------------------------------------
-- getOpenEditors
--------------------------------------------------------------------------------

--- Collect information about all listed buffers
--- @return table { tabs: table[] }
local function get_open_editors()
  local current_buf = vim.api.nvim_get_current_buf()
  local tabs = {}

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[bufnr].buflisted then
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name ~= "" then
        tabs[#tabs + 1] = {
          uri = vim.uri_from_bufnr(bufnr),
          isActive = (bufnr == current_buf),
          label = vim.fn.fnamemodify(name, ":t"),
          languageId = vim.bo[bufnr].filetype ~= "" and vim.bo[bufnr].filetype or "plaintext",
          isDirty = vim.bo[bufnr].modified,
        }
      end
    end
  end

  return { tabs = tabs }
end

tools.register({
  name = "getOpenEditors",
  description = "Get the list of open editor tabs",
  inputSchema = {
    type = "object",
    properties = vim.empty_dict(),
  },
  handler = function(_params)
    local data = get_open_editors()
    return {
      content = { { type = "text", text = vim.json.encode(data) } },
    }
  end,
})

--------------------------------------------------------------------------------
-- getWorkspaceFolders
--------------------------------------------------------------------------------

--- Collect workspace folder information
--- @return table { success: boolean, folders: table[], rootPath: string }
local function get_workspace_folders()
  local cwd = vim.fn.getcwd()
  local folders = {
    {
      name = vim.fn.fnamemodify(cwd, ":t"),
      uri = "file://" .. cwd,
      path = cwd,
    },
  }

  -- Try to add LSP workspace folders if available
  local ok, lsp_folders = pcall(vim.lsp.buf.list_workspace_folders)
  if ok and lsp_folders and #lsp_folders > 0 then
    -- Track already-added paths to avoid duplicates
    local seen = { [cwd] = true }
    for _, folder_path in ipairs(lsp_folders) do
      if not seen[folder_path] then
        seen[folder_path] = true
        folders[#folders + 1] = {
          name = vim.fn.fnamemodify(folder_path, ":t"),
          uri = "file://" .. folder_path,
          path = folder_path,
        }
      end
    end
  end

  return {
    success = true,
    folders = folders,
    rootPath = cwd,
  }
end

tools.register({
  name = "getWorkspaceFolders",
  description = "Get the list of workspace folders",
  inputSchema = {
    type = "object",
    properties = vim.empty_dict(),
  },
  handler = function(_params)
    local data = get_workspace_folders()
    return {
      content = { { type = "text", text = vim.json.encode(data) } },
    }
  end,
})
