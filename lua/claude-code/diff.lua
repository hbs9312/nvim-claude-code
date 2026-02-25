--- Diff UI manager for openDiff tool
--- Manages diff sessions: buffer creation, layout, keymaps, accept/reject, cleanup.
--- Replaces middle editor windows in-place, keeping neo-tree and terminal fixed.

local util = require("claude-code.util")
local config = require("claude-code.config")

local M = {}

--- Diff index counter for progress display (increments for each diff shown)
local diff_index = 0

--- Total number of diffs in the current batch (updated as diffs arrive)
local batch_total = 0

--- Flag to suppress WinClosed auto-reject during cleanup/transition
local cleaning_up = false

--- Queue for pending diff requests (shown one at a time)
--- @type table[]
local pending_queue = {}

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
--- @field saved_middle table|nil saved middle windows for restore [{buf, width}]
--- @field saved_edges table|nil saved edge windows [{win, orig_fixwidth}]
--- @field extra_win number|nil extra window created for diff (to close on restore)
--- @field augroup number|nil autocmd group id
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

--- Get configured accept/reject key tables (normalized to arrays)
--- @return string[] accept_keys
--- @return string[] reject_keys
local function get_keymap_keys()
  local accept_keys = config.values.diff and config.values.diff.keymaps and config.values.diff.keymaps.accept
    or { "<CR>", "ga" }
  local reject_keys = config.values.diff and config.values.diff.keymaps and config.values.diff.keymaps.reject
    or { "q", "gx" }
  if type(accept_keys) == "string" then accept_keys = { accept_keys } end
  if type(reject_keys) == "string" then reject_keys = { reject_keys } end
  return accept_keys, reject_keys
end

--- Build winbar string for a diff window
--- @param index_part string e.g. "[1/3] "
--- @param label string e.g. "Original" or "Proposed"
--- @param hl_group string highlight group for label
--- @param filename string file basename
--- @param hint_str string accept/reject hint suffix
--- @return string
local function build_winbar(index_part, label, hl_group, filename, hint_str)
  return "  " .. index_part .. "%#" .. hl_group .. "#" .. label .. ": " .. filename .. "%*" .. hint_str
end

--- Apply winbar labels with keymap hints to diff windows
--- @param session DiffSession
local function apply_winbar(session)
  local filename = vim.fn.fnamemodify(session.new_file_path, ":t")
  local index_part = string.format("%%#ClaudeCodeDiffIndex#[%d/%d] ", session.diff_index, session.batch_total)

  local accept_keys, reject_keys = get_keymap_keys()
  local accept_hint = table.concat(accept_keys, "/")
  local reject_hint = table.concat(reject_keys, "/")

  local hint_str = "  %#ClaudeCodeDiffAcceptHint#✓ Accept (" .. accept_hint .. ")%*"
    .. "  %#ClaudeCodeDiffRejectHint#✗ Reject (" .. reject_hint .. ")%*"

  if session.old_win and vim.api.nvim_win_is_valid(session.old_win) then
    vim.wo[session.old_win].winbar = build_winbar(index_part, "Original", "ClaudeCodeDiffOriginal", filename, hint_str)
  end
  if session.new_win and vim.api.nvim_win_is_valid(session.new_win) then
    vim.wo[session.new_win].winbar = build_winbar(index_part, "Proposed", "ClaudeCodeDiffProposed", filename, hint_str)
  end
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

  -- Keep buffer modifiable so the user can edit proposed changes before accepting.
  -- The final buffer content is read on accept and sent back to CLI as final_content.

  return buf
end

--------------------------------------------------------------------------------
-- Accept / Reject
--------------------------------------------------------------------------------

--- Remove accept/reject keymaps from both buffers to prevent duplicate input
--- @param session DiffSession
local function remove_keymaps(session)
  local accept_keys, reject_keys = get_keymap_keys()

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
    util.log_info("Diff accepted: %s", session.new_file_path)

    -- Emit user event
    pcall(vim.api.nvim_exec_autocmds, "User", {
      pattern = "ClaudeCodeDiffAccepted",
      data = { filePath = session.new_file_path },
    })

    -- Read final content from the proposed (new) buffer.
    -- The user may have edited it in the diff view, so read the buffer, not the original string.
    local final_content = session.new_file_contents
    if session.new_buf and vim.api.nvim_buf_is_valid(session.new_buf) then
      local content_lines = vim.api.nvim_buf_get_lines(session.new_buf, 0, -1, false)
      final_content = table.concat(content_lines, "\n")
      -- Preserve trailing newline if buffer has eol set
      if #content_lines > 0 and vim.bo[session.new_buf].eol then
        final_content = final_content .. "\n"
      end
    end

    -- Send deferred MCP response with file content.
    -- CLI handles the actual file write after receiving this response.
    if session.send_response then
      session.send_response({
        content = {
          { type = "text", text = "FILE_SAVED" },
          { type = "text", text = final_content },
        },
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
        content = {
          { type = "text", text = "DIFF_REJECTED" },
          { type = "text", text = session.tab_name or session.new_file_path },
        },
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

  local accept_keys, reject_keys = get_keymap_keys()

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

--- Set up autocmds for the diff session (WinClosed as reject safety net)
--- @param session DiffSession
local function setup_autocmds(session)
  session.augroup = vim.api.nvim_create_augroup("ClaudeDiff_" .. session.id, { clear = true })

  -- Use WinClosed on both diff windows — fires when the user closes a diff window
  -- (e.g. :q, :close), triggers auto-reject if not yet resolved.
  for _, win in ipairs({ session.old_win, session.new_win }) do
    if win and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_create_autocmd("WinClosed", {
        group = session.augroup,
        pattern = tostring(win),
        once = true,
        callback = function()
          if not session.resolved and not cleaning_up then
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

--- Classify windows in the current tab into edge (neo-tree, terminal) and middle (editor).
--- @return table middle_wins sorted left-to-right [{win, buf, width}]
--- @return table edge_wins [{win, orig_fixwidth}]
local function classify_windows()
  local main = require("claude-code")
  local term_buf = main.get_term_bufnr()
  local all_wins = vim.api.nvim_tabpage_list_wins(0)
  local middle = {}
  local edges = {}

  for _, win in ipairs(all_wins) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.bo[buf].filetype
    local is_neo_tree = ft == "neo-tree"
    local is_terminal = term_buf and buf == term_buf
    if is_neo_tree or is_terminal then
      table.insert(edges, { win = win, orig_fixwidth = vim.wo[win].winfixwidth })
    else
      table.insert(middle, {
        win = win,
        buf = buf,
        width = vim.api.nvim_win_get_width(win),
      })
    end
  end

  -- Sort by column position (left to right)
  table.sort(middle, function(a, b)
    return vim.api.nvim_win_get_position(a.win)[2] < vim.api.nvim_win_get_position(b.win)[2]
  end)

  return middle, edges
end

--- Create the diff layout: replace middle editor windows with Original | Proposed.
--- Keeps neo-tree (left) and Claude terminal (right) untouched.
--- @param session DiffSession
local function create_layout(session)
  local middle, edges = classify_windows()

  -- Lock edge windows (neo-tree, terminal) so Neovim won't resize them
  session.saved_edges = edges
  for _, e in ipairs(edges) do
    if vim.api.nvim_win_is_valid(e.win) then
      vim.wo[e.win].winfixwidth = true
    end
  end

  -- Save middle windows state for restore
  session.saved_middle = {}
  for _, m in ipairs(middle) do
    table.insert(session.saved_middle, { buf = m.buf, width = m.width })
  end

  -- Reuse the first middle window for old_buf, close the rest
  if #middle > 0 then
    local first_win = middle[1].win
    vim.api.nvim_win_set_buf(first_win, session.old_buf)
    session.old_win = first_win

    -- Close extra middle windows (reverse order to avoid shifting)
    for i = #middle, 2, -1 do
      pcall(vim.api.nvim_win_close, middle[i].win, true)
    end

    -- Create right split for proposed buffer
    vim.api.nvim_set_current_win(first_win)
    vim.cmd("rightbelow vsplit")
    local new_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(new_win, session.new_buf)
    session.new_win = new_win
    session.extra_win = new_win -- track the window we created
  else
    -- Fallback: no middle windows, create splits from scratch
    vim.cmd("vsplit")
    session.new_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(session.new_win, session.new_buf)
    vim.cmd("leftabove vsplit")
    session.old_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(session.old_win, session.old_buf)
    session.extra_win = session.new_win
  end

  -- Apply diff mode on both windows
  vim.api.nvim_win_call(session.old_win, function() vim.cmd("diffthis") end)
  vim.api.nvim_win_call(session.new_win, function() vim.cmd("diffthis") end)

  -- Apply winbar
  apply_winbar(session)

  -- Focus proposed (new) window so user sees changes first
  vim.api.nvim_set_current_win(session.new_win)
end

--- Restore the original middle window layout from saved state
--- @param session DiffSession
local function restore_layout(session)
  local saved = session.saved_middle or {}

  if #saved > 0 and session.old_win and vim.api.nvim_win_is_valid(session.old_win) then
    -- Close the extra split we created (new_win), keep old_win for restore
    if session.extra_win and vim.api.nvim_win_is_valid(session.extra_win) then
      pcall(vim.api.nvim_win_close, session.extra_win, true)
    end

    -- Restore first saved buffer in the remaining window
    local base_win = session.old_win
    if vim.api.nvim_buf_is_valid(saved[1].buf) then
      vim.api.nvim_win_set_buf(base_win, saved[1].buf)
    end
    pcall(vim.api.nvim_win_set_width, base_win, saved[1].width)

    -- Recreate additional middle windows
    local prev_win = base_win
    for i = 2, #saved do
      vim.api.nvim_set_current_win(prev_win)
      vim.cmd("rightbelow vsplit")
      local win = vim.api.nvim_get_current_win()
      if vim.api.nvim_buf_is_valid(saved[i].buf) then
        vim.api.nvim_win_set_buf(win, saved[i].buf)
      end
      pcall(vim.api.nvim_win_set_width, win, saved[i].width)
      prev_win = win
    end

    -- Focus the first restored window
    pcall(vim.api.nvim_set_current_win, base_win)
  else
    -- No saved state, just close diff windows
    if session.old_win and vim.api.nvim_win_is_valid(session.old_win) then
      pcall(vim.api.nvim_win_close, session.old_win, true)
    end
    if session.new_win and vim.api.nvim_win_is_valid(session.new_win) then
      pcall(vim.api.nvim_win_close, session.new_win, true)
    end
  end

  -- Restore original winfixwidth on edge windows
  if session.saved_edges then
    for _, e in ipairs(session.saved_edges) do
      if vim.api.nvim_win_is_valid(e.win) then
        vim.wo[e.win].winfixwidth = e.orig_fixwidth
      end
    end
  end
end

--- Transition directly to the next queued diff by reusing existing windows.
--- Avoids restore→recreate cycle which can trigger spurious WinClosed events.
--- @param prev_session DiffSession
--- @param next_params table
--- @param next_send_response function
local function transition_to_next(prev_session, next_params, next_send_response)
  session_counter = session_counter + 1
  local session_id = tostring(session_counter)
  diff_index = diff_index + 1

  -- Create new scratch buffers
  local new_old_buf = create_old_buffer(next_params.old_file_path, session_id)
  local new_new_buf = create_new_buffer(next_params.new_file_path, next_params.new_file_contents, session_id)

  -- Swap buffers in existing windows (old scratch buffers auto-wipe via bufhidden=wipe)
  local old_win = prev_session.old_win
  local new_win = prev_session.new_win
  vim.api.nvim_win_set_buf(old_win, new_old_buf)
  vim.api.nvim_win_set_buf(new_win, new_new_buf)

  -- Re-apply diff mode
  vim.api.nvim_win_call(old_win, function() vim.cmd("diffthis") end)
  vim.api.nvim_win_call(new_win, function() vim.cmd("diffthis") end)

  -- Create new session, transferring saved layout state from previous session
  --- @type DiffSession
  local session = {
    id = session_id,
    diff_index = diff_index,
    batch_total = batch_total,
    old_file_path = next_params.old_file_path,
    new_file_path = next_params.new_file_path,
    new_file_contents = next_params.new_file_contents,
    tab_name = next_params.tab_name or "",
    resolved = false,
    send_response = next_send_response,
    old_buf = new_old_buf,
    new_buf = new_new_buf,
    old_win = old_win,
    new_win = new_win,
    extra_win = prev_session.extra_win, -- transfer ownership
    saved_middle = prev_session.saved_middle, -- transfer for final restore
    saved_edges = prev_session.saved_edges, -- transfer for final restore
    augroup = nil,
  }

  -- Clear transferred refs from previous session so cleanup doesn't double-free
  prev_session.extra_win = nil
  prev_session.saved_middle = nil
  prev_session.saved_edges = nil

  -- Apply winbar, keymaps, autocmds
  apply_winbar(session)
  setup_keymaps(session)
  setup_autocmds(session)

  -- Track
  sessions[session_id] = session

  -- Focus proposed window
  vim.api.nvim_set_current_win(new_win)

  util.log_info("Diff transitioned: %s [%d/%d] (%s)", session_id, diff_index, batch_total, session.new_file_path)
end

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------

--- Clean up a diff session: restore original editor windows, remove autocmds.
--- If there are queued diffs, transitions directly to the next one without restoring.
--- Scratch buffers are automatically wiped via bufhidden=wipe.
--- @param session DiffSession
function M.cleanup(session)
  -- Remove from active sessions
  sessions[session.id] = nil

  -- Suppress WinClosed auto-reject during the entire cleanup/transition
  cleaning_up = true

  -- Delete the augroup first to prevent autocmds from firing during cleanup
  if session.augroup then
    pcall(vim.api.nvim_del_augroup_by_id, session.augroup)
    session.augroup = nil
  end

  -- Turn off diff mode on both windows
  for _, win in ipairs({ session.old_win, session.new_win }) do
    if win and vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_call, win, function() vim.cmd("diffoff") end)
      pcall(function() vim.wo[win].winbar = "" end)
    end
  end

  -- Check if we can transition directly to the next queued diff
  local has_next = #pending_queue > 0
  local can_reuse = session.old_win and vim.api.nvim_win_is_valid(session.old_win)
    and session.new_win and vim.api.nvim_win_is_valid(session.new_win)

  if has_next and can_reuse then
    -- Direct transition: reuse windows, no restore/recreate cycle
    local next_diff = table.remove(pending_queue, 1)
    transition_to_next(session, next_diff.params, next_diff.send_response)
  else
    -- Last diff or windows gone: restore original layout
    restore_layout(session)
  end

  -- Clear remaining references and free large data
  session.old_buf = nil
  session.new_buf = nil
  session.old_win = nil
  session.new_win = nil
  session.extra_win = nil
  session.saved_middle = nil
  session.saved_edges = nil
  session.send_response = nil
  session.new_file_contents = nil

  -- Reset batch counters only when all sessions are done and queue is empty
  if next(sessions) == nil and #pending_queue == 0 then
    diff_index = 0
    batch_total = 0
  end

  cleaning_up = false
  util.log_debug("Diff session cleaned up: %s", session.id)
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Internal: create and display a diff session immediately (first diff in a batch).
--- @param params table
--- @param send_response fun(result: table)
--- @return DiffSession
local function show_now(params, send_response)
  -- Guard: if another session exists (race condition), queue instead
  if next(sessions) ~= nil then
    table.insert(pending_queue, { params = params, send_response = send_response })
    return nil
  end

  session_counter = session_counter + 1
  local session_id = tostring(session_counter)
  diff_index = diff_index + 1

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
    extra_win = nil,
    saved_middle = nil,
    augroup = nil,
  }

  -- Create scratch buffers
  session.old_buf = create_old_buffer(session.old_file_path, session_id)
  session.new_buf = create_new_buffer(session.new_file_path, session.new_file_contents, session_id)

  -- Create the diff layout (replace middle windows with diff + diffthis)
  create_layout(session)

  -- Set up keymaps (accept/reject) on both buffers
  setup_keymaps(session)

  -- Set up safety-net autocmds (WinClosed -> reject)
  setup_autocmds(session)

  -- Track the session
  sessions[session_id] = session

  util.log_info("Diff session opened: %s [%d/%d] (%s)", session_id, diff_index, batch_total, session.new_file_path)
  return session
end

--- Show a diff view for the given parameters.
--- This is the main entry point called by the openDiff tool handler.
--- If a diff is already showing, the request is queued and shown after the current one resolves.
--- @param params table { old_file_path, new_file_path, new_file_contents, tab_name }
--- @param send_response fun(result: table) callback to send deferred MCP response
function M.show(params, send_response)
  -- Ensure highlight groups are defined (default=true allows user overrides)
  setup_highlights()

  -- Count every incoming diff for progress display
  batch_total = batch_total + 1

  -- If a diff is already active, queue this one for later
  if next(sessions) ~= nil then
    table.insert(pending_queue, { params = params, send_response = send_response })
    -- Update batch_total on the active session's winbar
    for _, s in pairs(sessions) do
      s.batch_total = batch_total
    end
    util.log_info("Diff queued (%d pending): %s", #pending_queue, params.new_file_path)
    return nil
  end

  return show_now(params, send_response)
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
