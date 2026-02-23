# Phase 0-09: setup() Function, Config Validation

## Status: Completed

## Purpose

Implement the `require("claude-code").setup()` entry point. Merge user configuration with defaults and print warnings for invalid settings. Automatically start the server on setup call.

## Dependencies

- 01-project-structure (completed) -- init.lua, config.lua module files required

## Input

- User config table (optional):
  ```lua
  require("claude-code").setup({
    server = {
      host = "127.0.0.1",
      port = 0,
    },
    log = {
      level = "warn",
    },
    -- ... other settings
  })
  ```

## Output

- Merged config object (defaults + user settings)
- WebSocket server auto-start (depending on configuration)
- Lock file creation

## Implementation Plan

1. **Default Config** (`config.lua`)
   ```lua
   local defaults = {
     server = {
       host = "127.0.0.1",
       port = 0,
     },
     diff = {
       layout = "vsplit",
       auto_close = true,
       keymaps = {
         accept = { "<CR>", "ga" },
         reject = { "q", "gx" },
       },
     },
     selection = {
       enabled = true,
       debounce_ms = 300,
     },
     diagnostics = {
       enabled = true,
     },
     log = {
       level = "warn",
     },
   }
   ```
2. **Config Merge** (`config.lua`)
   - Use `vim.tbl_deep_extend("force", defaults, user_opts)`
   - Properly merge nested tables
3. **Config Validation** (`config.lua`)
   - Verify `server.host` is a string
   - Verify `server.port` is a number
   - Verify `log.level` is a valid value ("debug", "info", "warn", "error")
   - Print `vim.notify(msg, vim.log.levels.WARN)` for invalid settings
4. **setup() Function** (`init.lua`)
   - Call config merge and validation
   - Generate authToken (UUID v4)
   - Start TCP server (`server.start()`)
   - Create lock file (`lockfile.create()`)
   - Register VimLeavePre autocmd (cleanup callback)
   - Register user commands (:ClaudeCode, etc.)
5. **Prevent Duplicate Calls**
   - If `setup()` is called multiple times, clean up the previous instance and restart

## Acceptance Criteria

- [x] `require("claude-code").setup()` called with empty config uses defaults
- [x] User config properly merged with defaults when provided
- [x] Warning printed for invalid config values (not an error)
- [x] Server auto-starts after setup call
- [x] Lock file created after setup call
- [x] Previous instance cleaned up on duplicate setup call

## Reference Specs

- `specs/07-plugin-api.md` section 7.1 (configuration interface)
- `specs/07-plugin-api.md` section 7.3 (Lua API: start, stop, restart)

## Estimated Time: ~1 hour
