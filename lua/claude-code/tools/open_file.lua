--- openFile tool — Open a file in the editor with optional text range selection
local util = require("claude-code.util")
local tools = require("claude-code.tools")

--- Search buffer lines for a plain text pattern
--- @param bufnr number buffer handle
--- @param text string plain text to search for
--- @param start_from number|nil 1-indexed line to start searching from (default 1)
--- @return number|nil line 1-indexed line number where text was found, or nil
local function find_text(bufnr, text, start_from)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for i = (start_from or 1), #lines do
    if lines[i]:find(text, 1, true) then
      return i
    end
  end
  return nil
end

--- Handler for the openFile tool
--- @param params table tool parameters
--- @return table MCP content response
local function handler(params)
  local file_path = params.filePath
  if not file_path or file_path == "" then
    return {
      content = { { type = "text", text = "Error: filePath is required" } },
      isError = true,
    }
  end

  -- Check if path is a directory
  local stat = vim.loop.fs_stat(file_path)
  if stat and stat.type == "directory" then
    return {
      content = { { type = "text", text = "Error: path is a directory: " .. file_path } },
      isError = true,
    }
  end

  -- Open the file (vim.fn.fnameescape handles spaces and special chars)
  local ok, err = pcall(vim.cmd.edit, vim.fn.fnameescape(file_path))
  if not ok then
    return {
      content = { { type = "text", text = "Error opening file: " .. tostring(err) } },
      isError = true,
    }
  end

  local bufnr = vim.api.nvim_get_current_buf()

  -- Handle startText / endText range selection
  local start_text = params.startText
  local end_text = params.endText
  local select_to_eol = params.selectToEndOfLine

  if start_text and start_text ~= "" then
    local start_line = find_text(bufnr, start_text)
    if start_line then
      if end_text and end_text ~= "" then
        -- Find endText starting from the startText line
        local end_line = find_text(bufnr, end_text, start_line)
        if end_line then
          -- Create visual line selection from start_line to end_line
          vim.api.nvim_win_set_cursor(0, { start_line, 0 })
          vim.cmd("normal! V" .. end_line .. "G")
          if select_to_eol then
            -- In visual line mode, selection already extends to end of line
            -- Switch to character-wise visual and extend to end of last line
            vim.cmd("normal! " .. start_line .. "G0v" .. end_line .. "G$")
          end
        else
          -- endText not found — just move cursor to startText line
          vim.api.nvim_win_set_cursor(0, { start_line, 0 })
          util.log_warn("openFile: endText pattern not found: %s", end_text)
        end
      else
        -- Only startText, no endText — move cursor to that line
        vim.api.nvim_win_set_cursor(0, { start_line, 0 })
        if select_to_eol then
          -- Select from cursor to end of line
          vim.cmd("normal! v$")
        end
      end
      -- Scroll so the cursor / selection is visible (centered)
      vim.cmd("normal! zz")
    else
      util.log_warn("openFile: startText pattern not found: %s", start_text)
    end
  end

  -- Build response based on makeFrontmost
  local make_frontmost = params.makeFrontmost
  if make_frontmost == nil then
    make_frontmost = true
  end

  if make_frontmost then
    return {
      content = { { type = "text", text = "Opened file: " .. file_path } },
    }
  else
    local info = vim.json.encode({
      success = true,
      filePath = file_path,
      languageId = vim.bo[bufnr].filetype,
      lineCount = vim.api.nvim_buf_line_count(bufnr),
    })
    return {
      content = { { type = "text", text = info } },
    }
  end
end

-- Register the tool
tools.register({
  name = "openFile",
  description = "Open a file in the editor",
  inputSchema = {
    type = "object",
    properties = {
      filePath = {
        type = "string",
        description = "The path of the file to open",
      },
      preview = {
        type = "boolean",
        description = "Whether to open in preview mode (ignored in Neovim)",
      },
      startText = {
        type = "string",
        description = "Text pattern to find the start of a selection",
      },
      endText = {
        type = "string",
        description = "Text pattern to find the end of a selection",
      },
      selectToEndOfLine = {
        type = "boolean",
        description = "Whether to extend the selection to the end of the line",
      },
      makeFrontmost = {
        type = "boolean",
        description = "Whether to focus the editor window (default: true)",
      },
    },
    required = { "filePath" },
  },
  handler = handler,
})
