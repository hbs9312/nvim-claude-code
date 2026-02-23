# 07. Plugin API and Configuration

## 7.1 Configuration Interface

```lua
require("claude-code").setup({
  -- Server settings
  server = {
    host = "127.0.0.1",        -- Binding address (not recommended to change)
    port = 0,                   -- 0 = auto-select (10000~65535)
  },

  -- Diff UI settings
  diff = {
    layout = "vsplit",          -- "vsplit" | "tab"
    auto_close = true,          -- Auto-close after accept/reject
    keymaps = {
      accept = { "<CR>", "ga" },
      reject = { "q", "gx" },
    },
  },

  -- Selection tracking
  selection = {
    enabled = true,             -- Whether to send selection_changed
    debounce_ms = 300,          -- Debounce duration
  },

  -- Diagnostics integration
  diagnostics = {
    enabled = true,             -- Whether to send diagnostics_changed
  },

  -- Logging
  log = {
    level = "warn",             -- "debug" | "info" | "warn" | "error"
  },
})
```

## 7.2 User Commands

| Command | Description | Priority |
|---------|-------------|----------|
| `:ClaudeCode` | Launch Claude CLI in terminal (auto-sets environment variables) | P0 |
| `:ClaudeCodeStatus` | Display connection status, port, and channel info | P0 |
| `:ClaudeCodeStop` | Stop server, clean up resources | P1 |
| `:ClaudeCodeRestart` | Restart server | P1 |
| `:ClaudeAtMention` | Send current file/selection as @mention | P1 |
| `:ClaudeCodeLog` | Open log buffer | P2 |

## 7.3 Lua API (Programmatic Interface)

```lua
local claude = require("claude-code")

-- Server state
claude.is_running()          -- boolean
claude.get_port()            -- number | nil
claude.get_connection_info() -- { port, authToken, connected, clientInfo }

-- Manual control
claude.start()               -- Start server
claude.stop()                -- Stop server
claude.restart()             -- Restart

-- CLI launch
claude.open_terminal()       -- Launch Claude CLI in terminal (with environment variables)

-- @mention
claude.at_mention()          -- Send current file/selection
claude.at_mention(filepath, startline, endline) -- Send specified range
```

## 7.4 Events (autocmd User)

User events published by the plugin:

| Event | Description | data |
|-------|-------------|------|
| `ClaudeCodeServerStarted` | WebSocket server started | `{ port }` |
| `ClaudeCodeServerStopped` | Server stopped | `{}` |
| `ClaudeCodeClientConnected` | CLI connected | `{ clientInfo }` |
| `ClaudeCodeClientDisconnected` | CLI disconnected | `{}` |
| `ClaudeCodeDiffAccepted` | Diff accepted | `{ filePath }` |
| `ClaudeCodeDiffRejected` | Diff rejected | `{ filePath }` |

```lua
-- Usage example
vim.api.nvim_create_autocmd("User", {
  pattern = "ClaudeCodeClientConnected",
  callback = function(args)
    vim.notify("Claude Code connected!", vim.log.levels.INFO)
  end,
})
```

## 7.5 Statusline Integration

```lua
-- For use with lualine, etc.
local function claude_status()
  local claude = require("claude-code")
  if not claude.is_running() then return "" end
  if claude.is_connected() then return "✻ Claude" end
  return "✻ Claude (waiting)"
end
```

## 7.6 Module Structure (Expected)

```
lua/claude-code/
├── init.lua              -- setup(), public API
├── server.lua            -- WebSocket server (vim.uv TCP)
├── websocket.lua         -- WebSocket protocol (upgrade, frame)
├── mcp.lua               -- MCP protocol (JSON-RPC, initialize, tools)
├── tools/
│   ├── init.lua          -- Tool registry
│   ├── open_diff.lua     -- openDiff implementation
│   ├── open_file.lua     -- openFile implementation
│   ├── selection.lua     -- getCurrentSelection, getLatestSelection
│   ├── diagnostics.lua   -- getDiagnostics
│   ├── editors.lua       -- getOpenEditors, getWorkspaceFolders
│   └── documents.lua     -- checkDocumentDirty, saveDocument, close_tab
├── diff.lua              -- Diff UI management
├── notifications.lua     -- selection_changed, at_mentioned, diagnostics_changed
├── lockfile.lua          -- Lock file management
├── util.lua              -- Utilities (UUID generation, logging, etc.)
└── config.lua            -- Configuration management
```
