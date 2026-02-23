# claude-code.nvim

Neovim plugin that integrates [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) with Neovim via a built-in MCP (Model Context Protocol) server. Claude Code can read your editor state, open files, show diffs, access diagnostics, and more — all through a WebSocket connection.

## Requirements

- Neovim >= 0.10.0
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and available in `$PATH`

## Installation

### lazy.nvim

```lua
{
  "your-username/claude-code.nvim",
  config = function()
    require("claude-code").setup()
  end,
}
```

### packer.nvim

```lua
use {
  "your-username/claude-code.nvim",
  config = function()
    require("claude-code").setup()
  end,
}
```

### Manual

Clone this repository into your Neovim packages directory:

```sh
git clone https://github.com/your-username/claude-code.nvim \
  ~/.local/share/nvim/site/pack/plugins/start/claude-code.nvim
```

Then add to your `init.lua`:

```lua
require("claude-code").setup()
```

## Configuration

All options with their defaults:

```lua
require("claude-code").setup({
  server = {
    host = "127.0.0.1",
    port_range = { 10000, 65535 },
  },
  auto_start = true,           -- start MCP server on plugin load
  log = {
    level = "warn",            -- "debug" | "info" | "warn" | "error"
  },
  terminal = {
    mode = "vsplit",           -- "vsplit" | "external"
    split_side = "right",      -- "left" | "right"
    split_width_percentage = 0.4,
  },
  diagnostics = {
    enabled = true,            -- send diagnostics_changed notifications
  },
  diff = {
    auto_close = true,
    feedback_delay = 800,      -- ms, 0 to close immediately
    keymaps = {
      accept = { "<CR>", "ga" },
      reject = { "q", "gx" },
    },
  },
})
```

## Commands

| Command              | Description                                      |
| -------------------- | ------------------------------------------------ |
| `:ClaudeCode [mode]` | Open Claude CLI terminal (`vsplit` or `external`) |
| `:ClaudeCodeStart`   | Start the MCP server                             |
| `:ClaudeCodeStop`    | Stop the MCP server                              |
| `:ClaudeCodeRestart` | Restart the MCP server                            |
| `:ClaudeCodeStatus`  | Show server/connection status                     |
| `:ClaudeAtMention`   | Send current file/selection as @mention           |

`:ClaudeAtMention` supports visual range — select lines and run `:'<,'>ClaudeAtMention` to mention only the selected region.

## Lua API

```lua
local cc = require("claude-code")

cc.setup(opts)            -- Initialize the plugin
cc.start()                -- Start the MCP server
cc.stop()                 -- Stop the MCP server
cc.restart()              -- Restart the MCP server
cc.is_running()           -- Check if server is running (boolean)
cc.is_connected()         -- Check if a Claude client is connected (boolean)
cc.get_port()             -- Get the current server port (number|nil)
cc.statusline()           -- Statusline string: "Claude", "Claude (waiting)", or ""
cc.open_terminal(args)    -- Open Claude CLI terminal
cc.open_vsplit(args)      -- Open Claude CLI in a vertical split
cc.open_external()        -- Show command for external terminal usage
cc.at_mention(path, s, e) -- Send @mention notification
cc.status()               -- Print connection status
```

## Statusline

### Built-in

Add to your statusline:

```lua
vim.o.statusline = "%{%v:lua.require('claude-code').statusline()%} " .. vim.o.statusline
```

### lualine.nvim

```lua
require("lualine").setup({
  sections = {
    lualine_x = {
      { function() return require("claude-code").statusline() end },
    },
  },
})
```

## User Events

The plugin emits autocommand events you can hook into:

| Event                           | Data              | Description                  |
| ------------------------------- | ----------------- | ---------------------------- |
| `ClaudeCodeServerStarted`       | `{ port }`        | MCP server started           |
| `ClaudeCodeServerStopped`       | `{}`              | MCP server stopped           |
| `ClaudeCodeClientConnected`     | `{}`              | Claude CLI connected         |
| `ClaudeCodeClientDisconnected`  | `{}`              | Claude CLI disconnected      |
| `ClaudeCodeDiffAccepted`        | `{ filePath }`    | Diff was accepted            |
| `ClaudeCodeDiffRejected`        | `{ filePath }`    | Diff was rejected            |

Example:

```lua
vim.api.nvim_create_autocmd("User", {
  pattern = "ClaudeCodeClientConnected",
  callback = function()
    vim.notify("Claude connected!")
  end,
})
```

## Diff Workflow

When Claude proposes file changes, a side-by-side diff view opens in a new tab:

- **Left pane:** Original file content
- **Right pane:** Proposed changes (read-only)
- **Winbar** shows progress (`[1/3]`), file name, and keybinding hints

Default keymaps (configurable via `diff.keymaps`):

| Key          | Action |
| ------------ | ------ |
| `<CR>` / `ga` | Accept |
| `q` / `gx`   | Reject |

Accepting writes the proposed content to disk and reloads any open buffers for that file. Rejecting keeps the original unchanged. A brief feedback flash confirms your action before the diff tab closes.

## MCP Tools

The plugin exposes these tools to Claude CLI via MCP:

- **openFile** — Open a file at a specific line/column
- **openDiff** — Show side-by-side diff for proposed changes
- **getCurrentSelection** — Get the current cursor position/selection
- **getLatestSelection** — Get the most recent visual selection
- **getOpenEditors** — List all open editor buffers
- **getDiagnostics** — Get LSP diagnostics for files

## Integrations

### Neo-tree

Send files from [Neo-tree](https://github.com/nvim-neo-tree/neo-tree.nvim) to Claude CLI as @mentions:

```lua
require("neo-tree").setup({
  window = {
    mappings = {
      ["@"] = {
        function(state)
          local node = state.tree:get_node()
          if node.type == "file" then
            require("claude-code").at_mention(node:get_id())
          end
        end,
        desc = "Send to Claude CLI",
      },
    },
  },
})
```

Navigate to any file in Neo-tree and press `@` to send it as a file reference to the active Claude CLI session.

## FAQ

**Q: Claude CLI doesn't connect?**
Check that the MCP server is running with `:ClaudeCodeStatus`. If it shows "stopped", run `:ClaudeCodeStart`. Make sure you're launching Claude CLI with the `--ide` flag (`:ClaudeCode` does this automatically).

**Q: How do I use this with an external terminal?**
Run `:ClaudeCode external` — it copies the shell command to your clipboard. Paste it into any terminal.

**Q: Diff view doesn't appear?**
The diff view requires Claude CLI to call the `openDiff` MCP tool. Ask Claude to edit a file and it will use this automatically.

## License

MIT
