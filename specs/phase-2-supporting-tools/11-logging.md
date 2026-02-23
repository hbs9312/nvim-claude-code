# Phase 2-11: Structured Logging, :ClaudeCodeLog

## Status: Pending

## Purpose

Implement a structured logging system and `:ClaudeCodeLog` command to facilitate debugging and problem diagnosis. Provides log level filtering, structured messages, and a log buffer display.

## Dependencies

- [x] Phase 0: Foundation Infrastructure (complete)
  - Base module structure

## Input

- **Log recording**: `log.debug()`, `log.info()`, `log.warn()`, `log.error()` calls from within the plugin
- **Log viewing**: User executes the `:ClaudeCodeLog` command
- **Configuration**: `log.level` option to control the log level

## Output

- **In-memory log buffer**: Stores the most recent N log entries (ring buffer)
- **:ClaudeCodeLog**: Displays log contents in a new buffer
- **File logging** (optional): Persistent storage to a file

### Log Entry Format

```
[2024-01-15 14:30:25] [INFO]  [server] Server started on port 12345
[2024-01-15 14:30:26] [DEBUG] [websocket] Frame received: text, 256 bytes
[2024-01-15 14:30:26] [INFO]  [mcp] Client initialized: Claude CLI v1.0.0
[2024-01-15 14:30:27] [WARN]  [tools] Tool handler slow: openDiff took 1500ms
[2024-01-15 14:30:28] [ERROR] [tools] Tool error [saveDocument]: E45: 'readonly' option is set
```

## Implementation Plan

### File Location

`lua/claude-code/log.lua`

### Implementation Steps

#### 1. Log Module Implementation

```lua
-- lua/claude-code/log.lua
local M = {}

local LEVELS = {
  debug = 1,
  info = 2,
  warn = 3,
  error = 4,
}

local config = {
  level = "warn",           -- Default log level
  max_entries = 1000,       -- Ring buffer max size
  file = nil,               -- File log path (nil = disabled)
}

local entries = {}          -- Log entry storage
local entry_count = 0

local function should_log(level)
  return LEVELS[level] >= LEVELS[config.level]
end

local function add_entry(level, module, message, data)
  if not should_log(level) then
    return
  end

  entry_count = entry_count + 1
  local entry = {
    timestamp = os.date("%Y-%m-%d %H:%M:%S"),
    level = level:upper(),
    module = module,
    message = message,
    data = data,
  }

  -- Ring buffer: remove oldest entry when max size exceeded
  table.insert(entries, entry)
  if #entries > config.max_entries then
    table.remove(entries, 1)
  end

  -- File logging (optional)
  if config.file then
    local f = io.open(config.file, "a")
    if f then
      f:write(M.format_entry(entry) .. "\n")
      f:close()
    end
  end
end
```

#### 2. Public API

```lua
function M.debug(module, message, data)
  add_entry("debug", module, message, data)
end

function M.info(module, message, data)
  add_entry("info", module, message, data)
end

function M.warn(module, message, data)
  add_entry("warn", module, message, data)
end

function M.error(module, message, data)
  add_entry("error", module, message, data)
end

function M.format_entry(entry)
  local line = string.format("[%s] [%-5s] [%s] %s",
    entry.timestamp,
    entry.level,
    entry.module,
    entry.message
  )
  if entry.data then
    line = line .. " " .. vim.inspect(entry.data)
  end
  return line
end

function M.get_entries(level_filter)
  if not level_filter then
    return entries
  end
  local filtered = {}
  for _, entry in ipairs(entries) do
    if LEVELS[entry.level:lower()] >= LEVELS[level_filter] then
      table.insert(filtered, entry)
    end
  end
  return filtered
end

function M.clear()
  entries = {}
  entry_count = 0
end

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})
end
```

#### 3. :ClaudeCodeLog Command

```lua
vim.api.nvim_create_user_command("ClaudeCodeLog", function(opts)
  local log = require("claude-code.log")
  local level_filter = opts.args ~= "" and opts.args or nil

  -- Create new buffer
  vim.cmd("new")
  local bufnr = vim.api.nvim_get_current_buf()
  vim.bo[bufnr].buftype = "nofile"
  vim.bo[bufnr].bufhidden = "wipe"
  vim.bo[bufnr].swapfile = false
  vim.bo[bufnr].filetype = "claude-code-log"

  -- Populate log contents
  local lines = {}
  for _, entry in ipairs(log.get_entries(level_filter)) do
    table.insert(lines, log.format_entry(entry))
  end

  if #lines == 0 then
    lines = { "-- No log entries --" }
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false

  -- Jump to last line (most recent log)
  vim.cmd("normal! G")
end, {
  nargs = "?",
  complete = function()
    return { "debug", "info", "warn", "error" }
  end,
})
```

#### 4. Internal Plugin Usage Examples

```lua
-- server.lua
local log = require("claude-code.log")

function M.start()
  log.info("server", "Starting MCP server...")
  -- ...
  log.info("server", "Server started on port " .. port)
end

-- mcp.lua
function handle_tools_call(request)
  log.debug("mcp", "tools/call: " .. request.params.name, request.params.arguments)
  -- ...
  log.info("mcp", "Tool completed: " .. tool_name, { duration_ms = elapsed })
end

-- websocket.lua
function on_error(err)
  log.error("websocket", "Connection error: " .. tostring(err))
end
```

### Performance Considerations

- The `should_log()` check is performed first to avoid unnecessary string formatting
- Ring buffer limits memory usage (default 1000 entries)
- File I/O is synchronous, so be cautious about using file logging at the debug level
- `vim.inspect(data)` is expensive, so it is only called when data is present

## Acceptance Criteria

- [ ] Log level filtering works correctly (debug setting shows all levels, error setting shows only errors)
- [ ] `:ClaudeCodeLog` displays log contents in a new buffer
- [ ] `:ClaudeCodeLog debug` enables level filtering
- [ ] Log entries include timestamp, level, module, and message
- [ ] Ring buffer does not exceed maximum size
- [ ] Log buffer is read-only (not modifiable)
- [ ] Logging has minimal impact on plugin performance
- [ ] Logs can be cleared with `log.clear()`

## Reference Specs

- [07-plugin-api.md section 7.1](../07-plugin-api.md) - `log.level` setting
- [07-plugin-api.md section 7.2](../07-plugin-api.md) - `:ClaudeCodeLog` command

## Estimated Time: ~1.5 hours
