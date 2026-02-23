--- Diff UI manager for openDiff tool
--- Manages diff sessions: buffer creation, layout, keymaps, accept/reject, cleanup.

local util = require("claude-code.util")
local config = require("claude-code.config")

local M = {}

--- Diff index counter for progress display (increments for each diff shown)
local diff_index = 0

--- Total number of diffs in the current batch (updated as diffs arrive)
local batch_total = 0

--- @class DiffSession
--- @field id string unique session identifier
--- @field diff_index number progress index for display
--- @field batch_total number total diffs in current batch at time of creation
--- @field old_buf number|nil old (original) scratch buffer handle
--- @field new_buf number|nil new (proposed) scratch buffer handle
--- @field old_win number|nil old window handle
--- @field new_win number|nil new window handle
--- @field old_file_path string original file path
--- @field new_file_path string target file path for writing
--- @field new_file_contents string proposed file contents
--- @field tab_name string display name for the diff
--- @field diff_tab number|nil tabpage handle for the diff tab
--- @field augroup number|nil autocmd group id
--- @field saved_layout table|nil { win: number, buf: number, tab: number }
--- @field resolved boolean whether accept/reject has been called
--- @field send_response fun(result: table)|nil callback to send deferred MCP response

--- Active diff sessions keyed by session id
--- @type table<string, DiffSession>
local sessions = {}

--- Counter for unique session ids
local session_counter = 0

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

--- Infer filetype from a file path using Neovim's filetype detection
--- @param filepath string
--- @return string|nil filetype
local function detect_filetype(filepath)
  local ft = vim.filetype.match({ filename = filepath })
  return ft
end

--- Create a scratch buffer with standard options
--- @param name string buffer name
--- @return number bufnr
local function create_scratch_buf(name)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  -- Set a unique name to avoid conflicts; pcall in case name already exists
  pcall(vim.api.nvim_buf_set_name, buf, name)
  return buf
end

--------------------------------------------------------------------------------
-- Highlights
--------------------------------------------------------------------------------

--- Define highlight groups for diff UI (default=true so users can override)
local function setup_highlights()
  local function hi(name, opts)
    opts.default = true
    vim.api.nvim_set_hl(0, name, opts)
  end

  hi("ClaudeCodeDiffIndex", { link = "Title" })
  hi("ClaudeCodeDiffOriginal", { link = "Comment" })
  hi("ClaudeCodeDiffProposed", { link = "Function" })
  hi("ClaudeCodeDiffAcceptHint", { fg = "#50fa7b", bold = true })
  hi("ClaudeCodeDiffRejectHint", { fg = "#ff5555", bold = true })
  hi("ClaudeCodeDiffHintDim", { link = "NonText" })
  hi("ClaudeCodeDiffAccepted", { fg = "#50fa7b", bg = "#1a3a1a" })
  hi("ClaudeCodeDiffRejected", { fg = "#ff5555", bg = "#3a1a1a" })
end

--------------------------------------------------------------------------------
-- Buffer creation
--------------------------------------------------------------------------------

--- Create the old (original) scratch buffer
--- @param old_file_path string
--- @param session_id string
--- @return number bufnr
local function create_old_buffer(old_file_path, session_id)
  local buf = create_scratch_buf("claude-diff://original/" .. session_id .. "/" .. vim.fn.fnamemodify(old_file_path, ":t"))

  -- Read from disk (ignores dirty buffers intentionally)
  if vim.fn.filereadable(old_file_path) == 1 then
    local lines = vim.fn.readfile(old_file_path)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end
  -- If file doesn't exist, buffer stays empty (new file case)

  -- Set filetype based on file extension
  local ft = detect_filetype(old_file_path)
  if ft then
    vim.bo[buf].filetype = ft
  end

  return buf
end

--- Create the new (proposed) scratch buffer
--- @param new_file_path string
--- @param new_file_contents string
--- @param session_id string
--- @return number bufnr
local function create_new_buffer(new_file_path, new_file_contents, session_id)
  local buf = create_scratch_buf("claude-diff://proposed/" .. session_id .. "/" .. vim.fn.fnamemodify(new_file_path, ":t"))

  -- Set proposed content
  local lines = vim.split(new_file_contents, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Set filetype based on file extension
  local ft = detect_filetype(new_file_path)
  if ft then
    vim.bo[buf].filetype = ft
  end

  -- Make readonly and non-modifiable
  vim.bo[buf].readonly = true
  vim.bo[buf].modifiable = false

  return buf
end

--------------------------------------------------------------------------------
-- Accept / Reject
--------------------------------------------------------------------------------

--- Remove accept/reject keymaps from both buffers to prevent duplicate input
--- @param session DiffSession
local function remove_keymaps(session)
  local accept_keys = config.values.diff and config.values.diff.keymaps and config.values.diff.keymaps.accept
    or { "<CR>", "ga" }
  local reject_keys = config.values.diff and config.values.diff.keymaps and config.values.diff.keymaps.reject
    or { "q", "gx" }
  if type(accept_keys) == "string" then accept_keys = { accept_keys } end
  if type(reject_keys) == "string" then reject_keys = { reject_keys } end

  for _, buf in ipairs({ session.old_buf, session.new_buf }) do
    if buf and vim.api.nvim_buf_is_valid(buf) then
      for _, key in ipairs(accept_keys) do
        pcall(vim.keymap.del, "n", key, { buffer = buf })
      end
      for _, key in ipairs(reject_keys) do
        pcall(vim.keymap.del, "n", key, { buffer = buf })
      end
    end
  end
end

--- Show feedback on winbar and schedule cleanup after delay
--- @param session DiffSession
--- @param action "accept"|"reject"
local function show_feedback(session, action)
  local filename = vim.fn.fnamemodify(session.new_file_path, ":t")
  local feedback_winbar
  if action == "accept" then
    feedback_winbar = "  %#ClaudeCodeDiffAccepted# ✓ Accepted: " .. filename .. " %*"
  else
    feedback_winbar = "  %#ClaudeCodeDiffRejected# ✗ Rejected: " .. filename .. " %*"
  end

  -- Update winbar on both windows
  for _, win in ipairs({ session.old_win, session.new_win }) do
    if win and vim.api.nvim_win_is_valid(win) then
      vim.wo[win].winbar = feedback_winbar
    end
  end
end

--- Resolve the diff session (accept or reject). Guarded against double-execution.
--- @param session DiffSession
--- @param action "accept"|"reject"
local function resolve(session, action)
  if session.resolved then
    return
  end
  session.resolved = true

  -- Remove keymaps immediately to prevent duplicate input
  remove_keymaps(session)

  if action == "accept" then
    -- Create parent directories if needed (new file case)
    local dir = vim.fn.fnamemodify(session.new_file_path, ":h")
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, "p")
    end

    -- Write new_file_contents to disk
    local lines = vim.split(session.new_file_contents, "\n", { plain = true })
    vim.fn.writefile(lines, session.new_file_path)

    -- If the file is already open in an existing buffer, reload it from disk
    local existing_buf = vim.fn.bufnr(session.new_file_path)
    if existing_buf ~= -1 and vim.api.nvim_buf_is_valid(existing_buf) then
      vim.api.nvim_buf_call(existing_buf, function()
        vim.cmd("edit!")
      end)
    end

    util.log_info("Diff accepted: %s", session.new_file_path)

    -- Emit user event
    pcall(vim.api.nvim_exec_autocmds, "User", {
      pattern = "ClaudeCodeDiffAccepted",
      data = { filePath = session.new_file_path },
    })

    -- Send deferred MCP response (before feedback delay so it doesn't block Claude CLI)
    if session.send_response then
      session.send_response({
        content = { { type = "text", text = "FILE_SAVED" } },
      })
    end
  else
    -- reject: keep original, do nothing to disk
    util.log_info("Diff rejected: %s", session.new_file_path)

    -- Emit user event
    pcall(vim.api.nvim_exec_autocmds, "User", {
      pattern = "ClaudeCodeDiffRejected",
      data = { filePath = session.new_file_path },
    })

    if session.send_response then
      session.send_response({
        content = { { type = "text", text = "DIFF_REJECTED" } },
      })
    end
  end

  -- Feedback flash: show result message, then clean up after delay
  local feedback_delay = config.values.diff and config.values.diff.feedback_delay or 800
  local notify_msg = action == "accept"
    and string.format("✓ Accepted: %s", session.new_file_path)
    or string.format("✗ Rejected: %s", session.new_file_path)
  local notify_level = action == "accept" and vim.log.levels.INFO or vim.log.levels.WARN

  if feedback_delay > 0 then
    show_feedback(session, action)
    vim.notify(notify_msg, notify_level)
    vim.defer_fn(function()
      M.cleanup(session)
    end, feedback_delay)
  else
    vim.notify(notify_msg, notify_level)
    M.cleanup(session)
  end
end

--------------------------------------------------------------------------------
-- Keymaps
--------------------------------------------------------------------------------

--- Set buffer-local keymaps on both old and new buffers
--- @param session DiffSession
local function setup_keymaps(session)
  local bufs = {}
  if session.old_buf and vim.api.nvim_buf_is_valid(session.old_buf) then
    bufs[#bufs + 1] = session.old_buf
  end
  if session.new_buf and vim.api.nvim_buf_is_valid(session.new_buf) then
    bufs[#bufs + 1] = session.new_buf
  end

  local accept_keys = config.values.diff and config.values.diff.keymaps and config.values.diff.keymaps.accept
    or { "<CR>", "ga" }
  local reject_keys = config.values.diff and config.values.diff.keymaps and config.values.diff.keymaps.reject
    or { "q", "gx" }

  -- Normalize to table if user passes a single string
  if type(accept_keys) == "string" then accept_keys = { accept_keys } end
  if type(reject_keys) == "string" then reject_keys = { reject_keys } end

  for _, buf in ipairs(bufs) do
    -- Accept keymaps
    for _, key in ipairs(accept_keys) do
      vim.keymap.set("n", key, function() resolve(session, "accept") end, {
        buffer = buf, nowait = true, silent = true, desc = "Accept diff (claude-code)",
      })
    end

    -- Reject keymaps
    for _, key in ipairs(reject_keys) do
      vim.keymap.set("n", key, function() resolve(session, "reject") end, {
        buffer = buf, nowait = true, silent = true, desc = "Reject diff (claude-code)",
      })
    end
  end
end

--------------------------------------------------------------------------------
-- Autocmds (safety net)
--------------------------------------------------------------------------------

--- Set up autocmds for the diff session (TabClosed as reject safety net)
--- @param session DiffSession
local function setup_autocmds(session)
  session.augroup = vim.api.nvim_create_augroup("ClaudeDiff_" .. session.id, { clear = true })

  -- Track the diff tab number for TabClosed detection
  local diff_tab = vim.api.nvim_get_current_tabpage()
  session.diff_tab = diff_tab

  -- Use WinClosed on both diff windows — fires when the user closes a diff window
  -- (e.g. :q, :close, or closing the tab), but NOT on simple tab switches.
  for _, win in ipairs({ session.old_win, session.new_win }) do
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_create_autocmd("WinClosed", {
        group = session.augroup,
        pattern = tostring(win),
        once = true,
        callback = function()
          if not session.resolved then
            vim.schedule(function()
              resolve(session, "reject")
            end)
          end
        end,
      })
    end
  end
end

--------------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------------

--- Create the diff layout: open a new tab, vsplit, diffthis
--- Uses a dedicated tab to avoid interference from existing window layout.
--- @param session DiffSession
local function create_layout(session)
  -- Save current layout for restoration
  session.saved_layout = {
    win = vim.api.nvim_get_current_win(),
    buf = vim.api.nvim_get_current_buf(),
    tab = vim.api.nvim_get_current_tabpage(),
  }

  -- Open a new tab to isolate the diff from existing layout
  vim.cmd("tabnew")
  local new_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(new_win, session.new_buf)
  session.new_win = new_win

  -- Split left for the old (original) buffer
  vim.cmd("leftabove vsplit")
  local old_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(old_win, session.old_buf)
  session.old_win = old_win

  -- Apply diffthis on both windows
  vim.api.nvim_win_call(old_win, function() vim.cmd("diffthis") end)
  vim.api.nvim_win_call(new_win, function() vim.cmd("diffthis") end)

  -- Set winbar labels with diff index and colored highlight groups
  local filename = vim.fn.fnamemodify(session.new_file_path, ":t")
  local index_part = string.format("%%#ClaudeCodeDiffIndex#[%d/%d] ", session.diff_index, session.batch_total)

  -- Build keymap hint from config
  local accept_keys = config.values.diff and config.values.diff.keymaps and config.values.diff.keymaps.accept
    or { "<CR>", "ga" }
  local reject_keys = config.values.diff and config.values.diff.keymaps and config.values.diff.keymaps.reject
    or { "q", "gx" }
  if type(accept_keys) == "string" then accept_keys = { accept_keys } end
  if type(reject_keys) == "string" then reject_keys = { reject_keys } end
  local accept_hint = table.concat(accept_keys, "/")
  local reject_hint = table.concat(reject_keys, "/")
  local hint = string.format(
    "%%#ClaudeCodeDiffAcceptHint#%s: Accept %%#ClaudeCodeDiffHintDim#| %%#ClaudeCodeDiffRejectHint#%s: Reject%%*",
    accept_hint, reject_hint
  )

  vim.wo[old_win].winbar = "  " .. index_part .. "%#ClaudeCodeDiffOriginal#Original: " .. filename .. "%*"
  vim.wo[new_win].winbar = "  " .. index_part .. "%#ClaudeCodeDiffProposed#Proposed: " .. filename .. "%*%= " .. hint .. "  "

  -- Focus the proposed (new) window so user sees changes first
  vim.api.nvim_set_current_win(new_win)
end

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------

--- Clean up a diff session: diffoff, bwipeout, remove autocmds, restore layout
--- @param session DiffSession
function M.cleanup(session)
  -- Remove from active sessions
  sessions[session.id] = nil

  -- Delete the augroup first to prevent BufWinLeave from firing during cleanup
  if session.augroup then
    pcall(vim.api.nvim_del_augroup_by_id, session.augroup)
    session.augroup = nil
  end

  -- diffoff on both windows
  if session.old_win and vim.api.nvim_win_is_valid(session.old_win) then
    vim.api.nvim_win_call(session.old_win, function()
      vim.cmd("diffoff")
    end)
  end
  if session.new_win and vim.api.nvim_win_is_valid(session.new_win) then
    vim.api.nvim_win_call(session.new_win, function()
      vim.cmd("diffoff")
    end)
  end

  -- Close the diff tab (this also wipes the scratch buffers via bufhidden=wipe)
  -- First, switch to the saved tab so closing the diff tab doesn't land us somewhere random
  if session.saved_layout and session.saved_layout.tab then
    if vim.api.nvim_tabpage_is_valid(session.saved_layout.tab) then
      pcall(vim.api.nvim_set_current_tabpage, session.saved_layout.tab)
    end
  end

  -- Close the diff tab if it still exists
  if session.diff_tab and vim.api.nvim_tabpage_is_valid(session.diff_tab) then
    -- tabclose requires tab number, not handle
    local tabnr = vim.api.nvim_tabpage_get_number(session.diff_tab)
    pcall(vim.cmd, tabnr .. "tabclose")
  else
    -- Fallback: wipe scratch buffers manually if tab is already gone
    if session.old_buf and vim.api.nvim_buf_is_valid(session.old_buf) then
      pcall(vim.api.nvim_buf_delete, session.old_buf, { force = true })
    end
    if session.new_buf and vim.api.nvim_buf_is_valid(session.new_buf) then
      pcall(vim.api.nvim_buf_delete, session.new_buf, { force = true })
    end
  end

  -- Restore focus to original window
  if session.saved_layout then
    if session.saved_layout.win and vim.api.nvim_win_is_valid(session.saved_layout.win) then
      pcall(vim.api.nvim_set_current_win, session.saved_layout.win)
    end
  end

  -- Clear references and free large data
  session.old_buf = nil
  session.new_buf = nil
  session.old_win = nil
  session.new_win = nil
  session.diff_tab = nil
  session.send_response = nil
  session.new_file_contents = nil

  -- Reset batch counters when all sessions are closed
  if next(sessions) == nil then
    diff_index = 0
    batch_total = 0
  end

  util.log_debug("Diff session cleaned up: %s", session.id)
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Show a diff view for the given parameters.
--- This is the main entry point called by the openDiff tool handler.
--- @param params table { old_file_path, new_file_path, new_file_contents, tab_name }
--- @param send_response fun(result: table) callback to send deferred MCP response
function M.show(params, send_response)
  -- Ensure highlight groups are defined (default=true allows user overrides)
  setup_highlights()

  session_counter = session_counter + 1
  local session_id = tostring(session_counter)

  -- Increment diff index for progress display
  diff_index = diff_index + 1
  batch_total = diff_index

  --- @type DiffSession
  local session = {
    id = session_id,
    diff_index = diff_index,
    batch_total = batch_total,
    old_file_path = params.old_file_path,
    new_file_path = params.new_file_path,
    new_file_contents = params.new_file_contents,
    tab_name = params.tab_name or "",
    resolved = false,
    send_response = send_response,
    old_buf = nil,
    new_buf = nil,
    old_win = nil,
    new_win = nil,
    diff_tab = nil,
    augroup = nil,
    saved_layout = nil,
  }

  -- Update batch_total on all existing sessions so their winbar reflects the new total
  for _, s in pairs(sessions) do
    s.batch_total = batch_total
  end

  -- Create scratch buffers
  session.old_buf = create_old_buffer(session.old_file_path, session_id)
  session.new_buf = create_new_buffer(session.new_file_path, session.new_file_contents, session_id)

  -- Create the diff layout (vsplit + diffthis)
  create_layout(session)

  -- Set up keymaps (accept/reject) on both buffers
  setup_keymaps(session)

  -- Set up safety-net autocmds (BufWinLeave -> reject)
  setup_autocmds(session)

  -- Track the session
  sessions[session_id] = session

  util.log_info("Diff session opened: %s (%s)", session_id, session.new_file_path)
  return session
end

--- Get all active diff sessions
--- @return table<string, DiffSession>
function M.get_active_sessions()
  return sessions
end

--- Close all active diff sessions (reject them)
--- @return number count of sessions closed
function M.close_all()
  local count = 0
  -- Collect ids first to avoid modifying table during iteration
  local ids = {}
  for id in pairs(sessions) do
    ids[#ids + 1] = id
  end
  for _, id in ipairs(ids) do
    local session = sessions[id]
    if session and not session.resolved then
      resolve(session, "reject")
      count = count + 1
    end
  end
  return count
end

return M
