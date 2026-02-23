--- Selection tracking and tools: getCurrentSelection, getLatestSelection, selection_changed
--- Tracks cursor position and visual selections via autocmds, exposes them as MCP tools,
--- and sends debounced selection_changed notifications over the WebSocket connection.

local tools = require("claude-code.tools")
local server = require("claude-code.server")
local util = require("claude-code.util")

local uv = vim.uv or vim.loop

local M = {}

--- @type table|nil Current selection/cursor info (updated on every cursor move)
M._current = nil

--- @type table|nil Latest meaningful selection (updated when leaving Visual mode)
M._latest = nil

--- @type userdata|nil Debounce timer for selection_changed notifications
local debounce_timer = nil

--- @type table|nil Last selection sent via notification (for dedup)
local last_sent = nil

--- Debounce interval in milliseconds
local DEBOUNCE_MS = 300

--- @type number|nil Autocmd group id
local augroup_id = nil

--- Check if a buffer is a normal file buffer worth tracking
--- @param bufnr number
--- @return boolean
local function is_trackable_buffer(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return false
  end
  local buftype = vim.bo[bufnr].buftype
  -- Only track normal file buffers (buftype is empty for normal files)
  return buftype == ""
end

--- Get the visually selected text using getpos("v") and getpos(".")
--- Handles forward and backward selection, and all visual sub-modes (v, V, <C-V>).
--- @return string text, table start_pos {line, col} 1-indexed, table end_pos {line, col} 1-indexed
local function get_visual_text()
  local bufnr = vim.api.nvim_get_current_buf()
  local mode = vim.fn.mode()

  -- getpos returns {bufnr, line, col, off} — all 1-indexed
  local v_pos = vim.fn.getpos("v")
  local dot_pos = vim.fn.getpos(".")

  local start_line, start_col = v_pos[2], v_pos[3]
  local end_line, end_col = dot_pos[2], dot_pos[3]

  -- Normalize: ensure start <= end
  if start_line > end_line or (start_line == end_line and start_col > end_col) then
    start_line, end_line = end_line, start_line
    start_col, end_col = end_col, start_col
  end

  local text
  if mode == "V" then
    -- Visual line mode: full lines
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
    text = table.concat(lines, "\n")
    -- For line mode, start_col is 1 and end_col is end of last line
    start_col = 1
    local last_line = lines[#lines] or ""
    end_col = #last_line
  elseif mode == "\22" then
    -- Visual block mode (<C-V>): rectangular selection
    -- Normalize columns
    if start_col > end_col then
      start_col, end_col = end_col, start_col
    end
    local block_lines = {}
    for lnum = start_line, end_line do
      local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1] or ""
      -- Clamp columns to line length; cols are 1-indexed
      local s = math.min(start_col, #line + 1)
      local e = math.min(end_col, #line)
      if s <= #line then
        block_lines[#block_lines + 1] = line:sub(s, e)
      else
        block_lines[#block_lines + 1] = ""
      end
    end
    text = table.concat(block_lines, "\n")
  else
    -- Character-wise visual mode (v)
    -- nvim_buf_get_text: 0-indexed, end col is exclusive
    local lines = vim.api.nvim_buf_get_text(
      bufnr,
      start_line - 1, start_col - 1,
      end_line - 1, end_col,
      {}
    )
    text = table.concat(lines, "\n")
  end

  return text, { start_line, start_col }, { end_line, end_col }
end

--- Collect current selection/cursor info from the active buffer
--- @return table|nil info selection info table, or nil for non-trackable buffers
local function get_selection_info()
  local bufnr = vim.api.nvim_get_current_buf()
  if not is_trackable_buffer(bufnr) then
    return nil
  end

  local filepath = vim.api.nvim_buf_get_name(bufnr)
  local file_url = "file://" .. filepath
  local mode = vim.fn.mode()

  if mode:match("[vV\22]") then
    -- Visual mode: real selection
    local text, start_pos, end_pos = get_visual_text()
    return {
      text = text,
      filePath = filepath,
      fileUrl = file_url,
      selection = {
        start = { line = start_pos[1] - 1, character = start_pos[2] - 1 },
        ["end"] = { line = end_pos[1] - 1, character = end_pos[2] - 1 },
        isEmpty = false,
      },
    }
  else
    -- Normal / Insert mode: cursor position only
    local pos = vim.api.nvim_win_get_cursor(0) -- {line, col}: line 1-indexed, col 0-indexed
    return {
      text = "",
      filePath = filepath,
      fileUrl = file_url,
      selection = {
        start = { line = pos[1] - 1, character = pos[2] },
        ["end"] = { line = pos[1] - 1, character = pos[2] },
        isEmpty = true,
      },
    }
  end
end

--- Compare two selection info tables for equality (used for dedup)
--- @param a table|nil
--- @param b table|nil
--- @return boolean
local function selection_equal(a, b)
  if a == nil or b == nil then
    return a == b
  end
  return a.filePath == b.filePath
    and a.selection.start.line == b.selection.start.line
    and a.selection.start.character == b.selection.start.character
    and a.selection["end"].line == b.selection["end"].line
    and a.selection["end"].character == b.selection["end"].character
end

--- Schedule a debounced selection_changed notification
local function schedule_notification()
  if not debounce_timer then
    return
  end
  debounce_timer:stop()
  debounce_timer:start(DEBOUNCE_MS, 0, vim.schedule_wrap(function()
    local current = M._current
    if current and not selection_equal(current, last_sent) then
      last_sent = vim.deepcopy(current)
      -- Silently ignore if no client is connected
      pcall(server.send_notification, "selection_changed", {
        text = current.text,
        filePath = current.filePath,
        fileUrl = current.fileUrl,
        selection = current.selection,
      })
    end
  end))
end

--- Setup autocmds for selection tracking
function M.setup()
  -- Avoid double-setup
  if augroup_id then
    return
  end

  augroup_id = vim.api.nvim_create_augroup("ClaudeCodeSelection", { clear = true })

  -- Create the debounce timer
  debounce_timer = uv.new_timer()

  -- Track cursor movement in Normal and Insert modes
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = augroup_id,
    callback = function()
      if not server.is_client_connected() then
        return
      end
      M._current = get_selection_info()
      schedule_notification()
    end,
  })

  -- Track mode changes — especially Visual -> Normal to capture _latest
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = augroup_id,
    pattern = "*:*",
    callback = function(ev)
      if not server.is_client_connected() then
        return
      end
      -- The old mode is in the pattern before the colon
      local old_mode = ev.match:match("^([^:]+):")

      -- If we were in Visual mode, capture the selection before it's lost
      if old_mode and old_mode:match("[vV\22]") then
        -- We need to read the marks that were set when Visual mode ended.
        -- After leaving Visual mode, '< and '> are set.
        local bufnr = vim.api.nvim_get_current_buf()
        if is_trackable_buffer(bufnr) then
          local filepath = vim.api.nvim_buf_get_name(bufnr)
          local file_url = "file://" .. filepath

          local start_pos = vim.fn.getpos("'<") -- {bufnr, line, col, off} 1-indexed
          local end_pos = vim.fn.getpos("'>")

          local start_line = start_pos[2]
          local start_col = start_pos[3]
          local end_line = end_pos[2]
          local end_col = end_pos[3]

          -- Get the text of the last visual selection using '< and '> marks
          if start_line > 0 and end_line > 0 then
            -- nvim_buf_get_text: 0-indexed, end col is exclusive
            local ok, lines = pcall(
              vim.api.nvim_buf_get_text,
              bufnr,
              start_line - 1, start_col - 1,
              end_line - 1, end_col,
              {}
            )
            local text = ok and table.concat(lines, "\n") or ""

            M._latest = {
              text = text,
              filePath = filepath,
              fileUrl = file_url,
              selection = {
                start = { line = start_line - 1, character = start_col - 1 },
                ["end"] = { line = end_line - 1, character = end_col - 1 },
                isEmpty = false,
              },
            }
          end

          -- Send selection_changed immediately (bypassing debounce)
          -- so Claude CLI receives the selection before user switches to terminal
          if M._latest and not selection_equal(M._latest, last_sent) then
            last_sent = vim.deepcopy(M._latest)
            pcall(server.send_notification, "selection_changed", {
              text = M._latest.text,
              filePath = M._latest.filePath,
              fileUrl = M._latest.fileUrl,
              selection = M._latest.selection,
            })
          end
        end
      end

      -- Always update _current with fresh info
      M._current = get_selection_info()
      schedule_notification()
    end,
  })

  util.log_debug("Selection tracking started")
end

--- Teardown: stop tracking and clean up resources
function M.teardown()
  if augroup_id then
    vim.api.nvim_del_augroup_by_id(augroup_id)
    augroup_id = nil
  end

  if debounce_timer then
    if not debounce_timer:is_closing() then
      debounce_timer:stop()
      debounce_timer:close()
    end
    debounce_timer = nil
  end

  M._current = nil
  M._latest = nil
  last_sent = nil

  util.log_debug("Selection tracking stopped")
end

-- ---------------------------------------------------------------------------
-- Tool: getCurrentSelection
-- ---------------------------------------------------------------------------
tools.register({
  name = "getCurrentSelection",
  description = "Get the current selection in the active editor",
  inputSchema = {
    type = "object",
    properties = vim.empty_dict(),
  },
  handler = function(_params)
    -- Compute fresh — not from cache
    local info = get_selection_info()

    if not info then
      return {
        content = { {
          type = "text",
          text = vim.json.encode({
            success = false,
            message = "No active editor found",
          }),
        } },
      }
    end

    return {
      content = { {
        type = "text",
        text = vim.json.encode({
          success = true,
          text = info.text,
          filePath = info.filePath,
          selection = info.selection,
        }),
      } },
    }
  end,
})

-- ---------------------------------------------------------------------------
-- Tool: getLatestSelection
-- ---------------------------------------------------------------------------
tools.register({
  name = "getLatestSelection",
  description = "Get the most recent selection from the editor",
  inputSchema = {
    type = "object",
    properties = vim.empty_dict(),
  },
  handler = function(_params)
    local info = M._latest

    if not info then
      return {
        content = { {
          type = "text",
          text = vim.json.encode({
            success = false,
            message = "No selection history",
          }),
        } },
      }
    end

    return {
      content = { {
        type = "text",
        text = vim.json.encode({
          success = true,
          text = info.text,
          filePath = info.filePath,
          selection = info.selection,
        }),
      } },
    }
  end,
})

return M
