# Phase 3-02: lualine Component

## Status: ✅ Complete

## Purpose

Provide a component function that can display Claude Code's connection status in statusline plugins such as lualine. This allows users to see at a glance whether the Claude Code server is running and whether a client is connected.

## Dependencies

- [x] Phase 0: Foundation Infrastructure (Complete)
- [ ] Phase 1: Core Tools (Required, Incomplete)
- [ ] Phase 2: Auxiliary Tools (Required, Incomplete)

## Input

- Server running status (is_running)
- Client connection status (is_connected)

## Output

- Statusline string:
  - Server not running: empty string (not displayed)
  - Server running, client not connected: `"✻ Claude (waiting)"`
  - Server running, client connected: `"✻ Claude"`

## Implementation Plan

1. **Implement statusline function**
   - Provide `require("claude-code").statusline()` function
   - Internally query server/connection status and return the appropriate string

2. **lualine integration example**
   ```lua
   -- lualine configuration example
   lualine_x = {
     { require("claude-code").statusline },
   }
   ```

3. **Update on state changes**
   - Automatically update statusline on server start/stop, client connect/disconnect
   - Trigger `vim.cmd("redrawstatus")` or lualine refresh

## Verification Criteria

- [ ] Returns empty string when server is not running
- [ ] Returns `"✻ Claude (waiting)"` when server is running but client is not connected
- [ ] Returns `"✻ Claude"` when server is running and client is connected
- [ ] Can be used as a component in lualine
- [ ] Display updates immediately on state changes

## Reference Specs

- `07-plugin-api.md` Section 7.5

## Estimated Time: ~1 hour
