--- Plan preview & review module for Claude Code plan mode.
--- Uses PostToolUse hooks to detect plan file writes, then opens preview UI.

local config = require("claude-code.config")
local util = require("claude-code.util")

local uv = vim.uv or vim.loop

local M = {}

--- @class PlanComment
--- @field id number
--- @field line_start number 0-indexed
--- @field line_end number 0-indexed
--- @field selected_text string
--- @field section_heading string|nil
--- @field comment_text string
--- @field extmark_id number|nil

--- @class PlanSession
--- @field plan_path string
--- @field buf number
--- @field win number
--- @field term_win number|nil window that was showing the terminal (to restore)
--- @field term_bufnr number|nil terminal buffer that was displaced
--- @field comments PlanComment[]
--- @field ns number namespace id
--- @field augroup number

--- @type PlanSession|nil
local session = nil

--- @type number
local comment_counter = 0

--------------------------------------------------------------------------------
-- Highlights
--------------------------------------------------------------------------------

local function setup_highlights()
  local function hi(name, opts)
    opts.default = true
    vim.api.nvim_set_hl(0, name, opts)
  end

  hi("ClaudeCodePlanComment", { fg = "#f1fa8c", italic = true })
  hi("ClaudeCodePlanCommentMarker", { fg = "#ffb86c", bold = true })
  hi("ClaudeCodePlanSelectedText", { bg = "#3a3a1a" })
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

--- Get the plans directory path
--- @return string
local function get_plans_dir()
  local claude_config = os.getenv("CLAUDE_CONFIG_DIR")
  if claude_config and claude_config ~= "" then
    return claude_config .. "/plans"
  end
  return vim.fn.expand("~/.claude/plans")
end

--- Find the latest .md plan file in a directory
--- @param dir string
--- @return string|nil path
local function find_latest_plan(dir)
  local handle = uv.fs_scandir(dir)
  if not handle then
    return nil
  end

  local latest_path = nil
  local latest_mtime = 0

  while true do
    local name, ftype = uv.fs_scandir_next(handle)
    if not name then break end
    if (ftype == "file" or ftype == nil) and name:match("%.md$") then
      local full = dir .. "/" .. name
      local stat = uv.fs_stat(full)
      if stat and stat.mtime.sec > latest_mtime then
        latest_mtime = stat.mtime.sec
        latest_path = full
      end
    end
  end

  return latest_path
end

--- Find the nearest heading above a given line
--- @param bufnr number
--- @param line number 0-indexed
--- @return string|nil
local function find_section_heading(bufnr, line)
  for i = line, 0, -1 do
    local text = vim.api.nvim_buf_get_lines(bufnr, i, i + 1, false)[1]
    if text and text:match("^#+%s") then
      return text
    end
  end
  return nil
end

--- Check if a file path is a plan file
--- @param file_path string
--- @return boolean
local function is_plan_file(file_path)
  return file_path:match("/.claude/plans/[^/]+%.md$") ~= nil
end

--------------------------------------------------------------------------------
-- Buffer & Layout
--------------------------------------------------------------------------------

--- Create the plan preview buffer
--- @param path string
--- @return number bufnr
local function create_plan_buffer(path)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  pcall(vim.api.nvim_buf_set_name, buf, "claude-plan://" .. vim.fn.fnamemodify(path, ":t"))

  -- Read file content
  if vim.fn.filereadable(path) == 1 then
    local lines = vim.fn.readfile(path)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end

  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = false

  return buf
end

--- Create layout: replace the Claude terminal window with the plan buffer.
--- Falls back to vsplit if no terminal window is found.
--- @param ses PlanSession
local function create_layout(ses)
  local main = require("claude-code")
  local t_bufnr = main.get_term_bufnr()

  -- Try to find the terminal window and replace it
  if t_bufnr and vim.api.nvim_buf_is_valid(t_bufnr) then
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == t_bufnr then
        ses.term_win = win
        ses.term_bufnr = t_bufnr
        vim.api.nvim_win_set_buf(win, ses.buf)
        ses.win = win
        break
      end
    end
  end

  -- Fallback: open a new vsplit if no terminal window
  if not ses.win then
    vim.cmd("botright vsplit")
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, ses.buf)
    ses.win = win
  end

  -- Window options
  vim.wo[ses.win].wrap = true
  vim.wo[ses.win].linebreak = true
  vim.wo[ses.win].number = false
  vim.wo[ses.win].relativenumber = false
  vim.wo[ses.win].signcolumn = "no"

  local km = (config.values.plan or {}).keymaps or {}
  vim.wo[ses.win].winbar = "  Plan Preview: "
    .. vim.fn.fnamemodify(ses.plan_path, ":t")
    .. "  %#Comment#|  gc comment  "
    .. (km.submit or "<leader>ps") .. " submit  "
    .. (km.accept or "<leader>pa") .. " accept  "
    .. (km.close or "q") .. " close%*"

  vim.api.nvim_set_current_win(ses.win)
end

--------------------------------------------------------------------------------
-- Comments
--------------------------------------------------------------------------------

--- Add a comment to the current visual selection
--- @param ses PlanSession
function M.add_comment(ses)
  ses = ses or session
  if not ses then
    vim.notify("[claude-code] No plan session active", vim.log.levels.WARN)
    return
  end

  -- Get visual selection range
  local start_line = vim.fn.line("'<") - 1 -- 0-indexed
  local end_line = vim.fn.line("'>") - 1

  -- Get selected text
  local lines = vim.api.nvim_buf_get_lines(ses.buf, start_line, end_line + 1, false)
  local selected_text = table.concat(lines, "\n")

  -- Find section heading
  local heading = find_section_heading(ses.buf, start_line)

  vim.ui.input({ prompt = "Plan comment: " }, function(input)
    if not input or input == "" then return end

    comment_counter = comment_counter + 1

    --- @type PlanComment
    local comment = {
      id = comment_counter,
      line_start = start_line,
      line_end = end_line,
      selected_text = selected_text,
      section_heading = heading,
      comment_text = input,
      extmark_id = nil,
    }

    -- Add extmark with virtual lines below the selection end
    local virt_lines = {
      { { "  >> ", "ClaudeCodePlanCommentMarker" }, { "[" .. comment.id .. "] " .. input, "ClaudeCodePlanComment" } },
    }

    comment.extmark_id = vim.api.nvim_buf_set_extmark(ses.buf, ses.ns, end_line, 0, {
      virt_lines = virt_lines,
      virt_lines_above = false,
    })

    -- Highlight the selected text range
    for i = start_line, end_line do
      vim.api.nvim_buf_add_highlight(ses.buf, ses.ns, "ClaudeCodePlanSelectedText", i, 0, -1)
    end

    table.insert(ses.comments, comment)
    util.log_info("Plan comment #%d added", comment.id)
  end)
end

--- Clear all comments from the session
--- @param ses PlanSession|nil
function M.clear_comments(ses)
  ses = ses or session
  if not ses then
    vim.notify("[claude-code] No plan session active", vim.log.levels.WARN)
    return
  end

  vim.api.nvim_buf_clear_namespace(ses.buf, ses.ns, 0, -1)
  ses.comments = {}
  comment_counter = 0
  vim.notify("[claude-code] Plan comments cleared", vim.log.levels.INFO)
end

--------------------------------------------------------------------------------
-- Feedback compilation & submission
--------------------------------------------------------------------------------

--- Compile comments into a structured feedback message
--- @param ses PlanSession
--- @return string
local function compile_feedback(ses)
  if #ses.comments == 0 then
    return ""
  end

  local parts = { "Plan feedback:", "" }

  for _, c in ipairs(ses.comments) do
    local ref = string.format("@%s#%d-%d", ses.plan_path, c.line_start + 1, c.line_end + 1)
    parts[#parts + 1] = "- " .. ref .. " — " .. c.comment_text
  end

  return table.concat(parts, "\n")
end

--- Submit feedback to the Claude terminal
--- @param ses PlanSession|nil
function M.submit(ses)
  ses = ses or session
  if not ses then
    vim.notify("[claude-code] No plan session active", vim.log.levels.WARN)
    return
  end

  if #ses.comments == 0 then
    vim.notify("[claude-code] No comments to submit", vim.log.levels.WARN)
    return
  end

  local feedback = compile_feedback(ses)

  -- Try to send to Claude terminal
  local main = require("claude-code")
  local job_id = main.get_term_job_id()

  -- Close plan preview (restores terminal window)
  M.close()

  -- Copy feedback to clipboard and focus terminal for manual paste
  vim.fn.setreg("+", feedback)
  main.focus_terminal()
  vim.notify("[claude-code] Plan feedback copied — select feedback option and paste", vim.log.levels.INFO)
end

--- Accept the plan as-is: close preview, restore terminal, press Enter
--- @param ses PlanSession|nil
function M.accept(ses)
  ses = ses or session
  if not ses then
    vim.notify("[claude-code] No plan session active", vim.log.levels.WARN)
    return
  end

  local main = require("claude-code")
  local job_id = main.get_term_job_id()

  M.close()

  if job_id then
    vim.fn.chansend(job_id, "\r")
    main.focus_terminal()
  else
    vim.notify("[claude-code] No terminal found", vim.log.levels.WARN)
  end
end

--------------------------------------------------------------------------------
-- Plan reload
--------------------------------------------------------------------------------

--- Reload plan content from disk
--- @param ses PlanSession
local function reload_plan(ses)
  if not ses or not ses.buf or not vim.api.nvim_buf_is_valid(ses.buf) then
    return
  end

  if vim.fn.filereadable(ses.plan_path) ~= 1 then
    return
  end

  local lines = vim.fn.readfile(ses.plan_path)

  vim.bo[ses.buf].modifiable = true
  vim.api.nvim_buf_set_lines(ses.buf, 0, -1, false, lines)
  vim.bo[ses.buf].modifiable = false

  util.log_debug("Plan buffer reloaded: %s", ses.plan_path)
end

--------------------------------------------------------------------------------
-- Hook-based plan detection
--------------------------------------------------------------------------------

--- Get the path for the hook script
--- @return string
local function get_hook_script_path()
  return vim.fn.stdpath("data") .. "/claude-code/plan-hook.sh"
end

--- Write the hook script to disk
local function ensure_hook_script()
  local script_path = get_hook_script_path()
  local dir = vim.fn.fnamemodify(script_path, ":h")

  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end

  -- The hook receives JSON on stdin with tool_input.file_path
  -- $NVIM is set by Neovim for child processes (the Claude terminal)
  local script = table.concat({
    "#!/bin/bash",
    "# nvim-claude-code: PostToolUse hook for plan file detection",
    "# Auto-generated by nvim-claude-code plugin — do not edit",
    "",
    'file_path=$(jq -r ".tool_input.file_path // empty" 2>/dev/null)',
    "",
    'case "$file_path" in',
    "  */.claude/plans/*.md)",
    '    if [ -n "$NVIM" ]; then',
    [[      nvim --server "$NVIM" --remote-expr "v:lua._claude_plan_open('$file_path')" 2>/dev/null || true]],
    "    fi",
    "    ;;",
    "esac",
    "exit 0",
    "",
  }, "\n")

  vim.fn.writefile(vim.split(script, "\n", { plain = true }), script_path)
  vim.fn.setfperm(script_path, "rwxr-xr-x")
end

--- Check if the hook is already registered in a settings file
--- @param path string settings file path
--- @param script_path string hook script path to look for
--- @return boolean
local function hook_registered_in(path, script_path)
  if vim.fn.filereadable(path) ~= 1 then
    return false
  end
  local content = table.concat(vim.fn.readfile(path), "\n")
  local ok, parsed = pcall(vim.json.decode, content)
  if not ok or type(parsed) ~= "table" then
    return false
  end
  local post = (parsed.hooks or {}).PostToolUse or {}
  for _, entry in ipairs(post) do
    for _, h in ipairs(entry.hooks or {}) do
      if h.command == script_path then
        return true
      end
    end
  end
  return false
end

--- Register the hook in Claude's settings (if not already present)
local function register_hook()
  ensure_hook_script()

  local script_path = get_hook_script_path()
  local claude_dir = vim.fn.expand("~/.claude")

  -- Check all settings files where the hook might already be
  if hook_registered_in(claude_dir .. "/settings.json", script_path) then
    return
  end
  if hook_registered_in(claude_dir .. "/settings.local.json", script_path) then
    return
  end

  -- Not registered anywhere — add to settings.local.json
  local settings_path = claude_dir .. "/settings.local.json"
  local settings = {}

  if vim.fn.filereadable(settings_path) == 1 then
    local content = table.concat(vim.fn.readfile(settings_path), "\n")
    local ok, parsed = pcall(vim.json.decode, content)
    if ok and type(parsed) == "table" then
      settings = parsed
    end
  end

  settings.hooks = settings.hooks or {}
  settings.hooks.PostToolUse = settings.hooks.PostToolUse or {}

  table.insert(settings.hooks.PostToolUse, {
    matcher = "Write|Edit",
    hooks = {
      {
        type = "command",
        command = script_path,
      },
    },
  })

  local json = vim.json.encode(settings)
  vim.fn.writefile({ json }, settings_path)
  util.log_info("Plan hook registered in %s", settings_path)
end

--- Register global function called by hook via nvim --server
local function register_global_handler()
  _G._claude_plan_open = function(path)
    vim.schedule(function()
      if is_plan_file(path) then
        M.open(path)
      end
    end)
    return ""
  end
end

--- Remove global function
local function unregister_global_handler()
  _G._claude_plan_open = nil
end

--------------------------------------------------------------------------------
-- Keymaps
--------------------------------------------------------------------------------

--- Set up buffer-local keymaps for the plan buffer
--- @param ses PlanSession
local function setup_keymaps(ses)
  local cfg = config.values.plan or {}
  local km = cfg.keymaps or {}

  local buf = ses.buf

  -- gc (visual) → comment
  vim.keymap.set("v", km.comment or "gc", function()
    -- Exit visual mode first so '< and '> marks are set
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
    vim.schedule(function()
      M.add_comment(ses)
    end)
  end, { buffer = buf, nowait = true, silent = true, desc = "Add plan comment (claude-code)" })

  -- submit
  vim.keymap.set("n", km.submit or "<leader>ps", function()
    M.submit(ses)
  end, { buffer = buf, nowait = true, silent = true, desc = "Submit plan feedback (claude-code)" })

  -- clear
  vim.keymap.set("n", km.clear or "<leader>px", function()
    M.clear_comments(ses)
  end, { buffer = buf, nowait = true, silent = true, desc = "Clear plan comments (claude-code)" })

  -- accept
  vim.keymap.set("n", km.accept or "<leader>pa", function()
    M.accept(ses)
  end, { buffer = buf, nowait = true, silent = true, desc = "Accept plan (claude-code)" })

  -- close
  vim.keymap.set("n", km.close or "q", function()
    M.close()
  end, { buffer = buf, nowait = true, silent = true, desc = "Close plan preview (claude-code)" })

end

--------------------------------------------------------------------------------
-- Session lifecycle
--------------------------------------------------------------------------------

--- Open a plan preview session
--- @param path string|nil path to plan file (nil = latest)
function M.open(path)
  local cfg = config.values.plan or {}
  if not cfg.enabled then return end

  setup_highlights()

  -- Resolve path
  if not path then
    local plans_dir = get_plans_dir()
    path = find_latest_plan(plans_dir)
    if not path then
      vim.notify("[claude-code] No plan files found in " .. plans_dir, vim.log.levels.WARN)
      return
    end
  end

  -- If session exists with same path, just reload
  if session and session.plan_path == path then
    reload_plan(session)
    -- Focus the window
    if session.win and vim.api.nvim_win_is_valid(session.win) then
      vim.api.nvim_set_current_win(session.win)
    end
    return
  end

  -- Close existing session if different path
  if session then
    M.close()
  end

  -- Create new session
  local buf = create_plan_buffer(path)
  local ns = vim.api.nvim_create_namespace("claude_plan_comments")

  --- @type PlanSession
  local ses = {
    plan_path = path,
    buf = buf,
    win = nil,
    term_win = nil,
    term_bufnr = nil,
    comments = {},
    ns = ns,
    augroup = vim.api.nvim_create_augroup("ClaudePlan", { clear = true }),
  }

  create_layout(ses)
  setup_keymaps(ses)

  -- WinClosed: if the window is closed externally (e.g. :close),
  -- just clean up state — the window is already gone, nothing to restore.
  if ses.win and vim.api.nvim_win_is_valid(ses.win) then
    vim.api.nvim_create_autocmd("WinClosed", {
      group = ses.augroup,
      pattern = tostring(ses.win),
      once = true,
      callback = function()
        vim.schedule(function()
          if session then
            -- Window already gone, prevent close() from trying to restore
            session.term_win = nil
            session.term_bufnr = nil
            M.close()
          end
        end)
      end,
    })
  end

  session = ses

  vim.notify("[claude-code] Plan preview opened: " .. vim.fn.fnamemodify(path, ":t"), vim.log.levels.INFO)
  util.log_info("Plan session opened: %s", path)
end

--- Close the current plan session and restore the terminal buffer.
function M.close()
  if not session then return end

  local ses = session
  session = nil

  -- Delete augroup first to prevent WinClosed from re-firing
  if ses.augroup then
    pcall(vim.api.nvim_del_augroup_by_id, ses.augroup)
  end

  -- Restore terminal buffer to the window it was displaced from
  if ses.term_win and vim.api.nvim_win_is_valid(ses.term_win)
      and ses.term_bufnr and vim.api.nvim_buf_is_valid(ses.term_bufnr) then
    vim.api.nvim_win_set_buf(ses.term_win, ses.term_bufnr)
    -- plan buffer (bufhidden=wipe) is automatically wiped
  elseif ses.win and vim.api.nvim_win_is_valid(ses.win) then
    -- No terminal to restore — close the fallback window
    pcall(vim.api.nvim_win_close, ses.win, true)
  end

  -- Safety: explicitly delete plan buffer if still alive
  if ses.buf and vim.api.nvim_buf_is_valid(ses.buf) then
    pcall(vim.api.nvim_buf_delete, ses.buf, { force = true })
  end

  comment_counter = 0
  util.log_debug("Plan session closed")
end

--- Get the current session (for external use)
--- @return PlanSession|nil
function M.get_session()
  return session
end

--------------------------------------------------------------------------------
-- Module lifecycle
--------------------------------------------------------------------------------

--- Initialize the plan module (called from init.lua M.start)
function M.setup()
  local cfg = config.values.plan or {}
  if not cfg.enabled then return end

  setup_highlights()
  register_global_handler()
  register_hook()
end

--- Teardown the plan module (called from init.lua M.stop)
function M.teardown()
  unregister_global_handler()
  M.close()
end

return M









