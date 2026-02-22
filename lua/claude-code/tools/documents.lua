--- Document management tools — checkDocumentDirty, saveDocument, closeAllDiffTabs, close_tab
local tools = require("claude-code.tools")

--------------------------------------------------------------------------------
-- checkDocumentDirty
--------------------------------------------------------------------------------

tools.register({
  name = "checkDocumentDirty",
  description = "Check if a document has unsaved changes",
  inputSchema = {
    type = "object",
    properties = {
      filePath = {
        type = "string",
        description = "The path of the file to check",
      },
    },
    required = { "filePath" },
  },
  handler = function(params)
    local file_path = params.filePath
    local bufnr = vim.fn.bufnr(file_path)

    if bufnr == -1 or not vim.api.nvim_buf_is_loaded(bufnr) then
      local data = {
        success = false,
        message = "Document not open: " .. file_path,
      }
      return {
        content = { { type = "text", text = vim.json.encode(data) } },
      }
    end

    local data = {
      success = true,
      filePath = file_path,
      isDirty = vim.bo[bufnr].modified,
      isUntitled = false,
    }
    return {
      content = { { type = "text", text = vim.json.encode(data) } },
    }
  end,
})

--------------------------------------------------------------------------------
-- saveDocument
--------------------------------------------------------------------------------

tools.register({
  name = "saveDocument",
  description = "Save a document to disk",
  inputSchema = {
    type = "object",
    properties = {
      filePath = {
        type = "string",
        description = "The path of the file to save",
      },
    },
    required = { "filePath" },
  },
  handler = function(params)
    local file_path = params.filePath
    local bufnr = vim.fn.bufnr(file_path)

    if bufnr == -1 or not vim.api.nvim_buf_is_loaded(bufnr) then
      local data = {
        success = false,
        filePath = file_path,
        saved = false,
        message = "Document not open: " .. file_path,
      }
      return {
        content = { { type = "text", text = vim.json.encode(data) } },
      }
    end

    local ok, err = pcall(function()
      vim.api.nvim_buf_call(bufnr, function()
        vim.cmd("write")
      end)
    end)

    if ok then
      local data = {
        success = true,
        filePath = file_path,
        saved = true,
        message = "Document saved successfully",
      }
      return {
        content = { { type = "text", text = vim.json.encode(data) } },
      }
    else
      local data = {
        success = false,
        filePath = file_path,
        saved = false,
        message = "Failed to save: " .. tostring(err),
      }
      return {
        content = { { type = "text", text = vim.json.encode(data) } },
      }
    end
  end,
})

--------------------------------------------------------------------------------
-- closeAllDiffTabs
--------------------------------------------------------------------------------

tools.register({
  name = "closeAllDiffTabs",
  description = "Close all open diff tabs",
  inputSchema = {
    type = "object",
    properties = vim.empty_dict(),
  },
  handler = function(_params)
    local diff = require("claude-code.diff")
    local count = diff.close_all()
    return {
      content = { { type = "text", text = "closed " .. count .. " diff tabs" } },
    }
  end,
})

--------------------------------------------------------------------------------
-- close_tab (hidden tool — empty description)
--------------------------------------------------------------------------------

tools.register({
  name = "close_tab",
  description = "",
  inputSchema = {
    type = "object",
    properties = {
      tab_name = {
        type = "string",
      },
    },
    required = { "tab_name" },
  },
  handler = function(params)
    local tab_name = params.tab_name
    local bufnr = vim.fn.bufnr(tab_name)

    if bufnr ~= -1 and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end

    return {
      content = { { type = "text", text = "TAB_CLOSED" } },
    }
  end,
})
