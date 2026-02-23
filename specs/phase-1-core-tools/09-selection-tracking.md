# Phase 1-09: CursorMoved Tracking, Cache, 0-indexed Conversion

## Status: ✅ Complete

## Purpose

Track the current selection and cursor position in real time using `CursorMoved`, `CursorMovedI`, and `ModeChanged` autocmds, and store them in a cache. Convert Neovim's 1-indexed coordinates to the MCP protocol's 0-indexed format. This serves as the shared data layer for getCurrentSelection, getLatestSelection, and selection_changed.

## Dependencies

- [x] Phase 0: Foundation Infrastructure (complete)
- [ ] Phase 1-01: Tool Registration System (required, incomplete)

## Input

Neovim events:
- `CursorMoved` — cursor movement in Normal mode
- `CursorMovedI` — cursor movement in Insert mode
- `ModeChanged` — mode change (especially Visual → Normal transition)

## Output

Cached selection information:

```lua
{
  text = "selected content",        -- Selected text (can be empty string)
  filePath = "/absolute/path",      -- Absolute file path
  fileUrl = "file:///absolute/path", -- file:// URI
  selection = {
    start = { line = 0, character = 0 },  -- 0-indexed
    ["end"] = { line = 0, character = 10 }, -- 0-indexed
    isEmpty = false,                        -- Whether only a cursor is present
  },
}
```

## Implementation Plan

### File: `lua/claude-code/tools/selection.lua`

1. **Cache structure**
   ```lua
   local M = {}
   M._current = nil   -- Current selection/cursor info
   M._latest = nil    -- Last meaningful selection (Visual selection history)
   ```

2. **Collect current selection info**
   ```lua
   local function get_selection_info()
     local bufnr = vim.api.nvim_get_current_buf()
     local filepath = vim.api.nvim_buf_get_name(bufnr)

     -- Return nil if there is no file path (e.g., scratch buffer)
     if filepath == "" then return nil end

     local mode = vim.fn.mode()

     if mode:match("[vV\22]") then
       -- Visual mode: selection range
       local start_pos = vim.fn.getpos("v")    -- [bufnr, line, col, off]
       local end_pos = vim.fn.getpos(".")      -- cursor position
       local text = get_visual_text()

       return {
         text = text,
         filePath = filepath,
         fileUrl = "file://" .. filepath,
         selection = {
           start = { line = start_pos[2] - 1, character = start_pos[3] - 1 },
           ["end"] = { line = end_pos[2] - 1, character = end_pos[3] - 1 },
           isEmpty = false,
         },
       }
     else
       -- Normal/Insert mode: cursor position
       local pos = vim.api.nvim_win_get_cursor(0)  -- {line, col} 1-indexed line, 0-indexed col

       return {
         text = "",
         filePath = filepath,
         fileUrl = "file://" .. filepath,
         selection = {
           start = { line = pos[1] - 1, character = pos[2] },  -- line: 1→0, col: already 0-indexed
           ["end"] = { line = pos[1] - 1, character = pos[2] },
           isEmpty = true,
         },
       }
     end
   end
   ```

3. **Extract Visual text**
   ```lua
   local function get_visual_text()
     -- Get text from Visual mode
     local start_pos = vim.fn.getpos("v")
     local end_pos = vim.fn.getpos(".")
     -- Normalize start/end (handle reverse selection)
     -- Use vim.api.nvim_buf_get_text()
   end
   ```

4. **Autocmd setup**
   ```lua
   function M.setup()
     local augroup = vim.api.nvim_create_augroup("ClaudeSelection", { clear = true })

     vim.api.nvim_create_autocmd({"CursorMoved", "CursorMovedI"}, {
       group = augroup,
       callback = function()
         M._current = get_selection_info()
       end,
     })

     vim.api.nvim_create_autocmd("ModeChanged", {
       group = augroup,
       pattern = "*:*",
       callback = function()
         local info = get_selection_info()
         M._current = info
         -- Save to latest when leaving Visual mode
         if info and not info.selection.isEmpty then
           M._latest = vim.deepcopy(info)
         end
       end,
     })
   end
   ```

5. **0-indexed conversion notes**
   - Neovim `line`: 1-indexed → 0-indexed: `line - 1`
   - Neovim `nvim_win_get_cursor` col: already 0-indexed (no conversion needed)
   - Neovim `getpos()` col: 1-indexed → 0-indexed: `col - 1`

## Acceptance Criteria

- [ ] `_current` cache updates on Normal mode cursor movement
- [ ] Text and range information are accurately cached during Visual mode selection
- [ ] Last selection is saved to `_latest` on Visual → Normal transition
- [ ] 0-indexed conversion: line 1, col 1 → line 0, character 0
- [ ] Returns nil for scratch buffers (no path)
- [ ] Reverse Visual selection (bottom → top) is handled correctly
- [ ] fileUrl includes the file:// protocol

## Reference Specs

- [04-tools.md](../04-tools.md) Section 4.4 — getCurrentSelection
- [04-tools.md](../04-tools.md) Section 4.5 — getLatestSelection
- [05-notifications.md](../05-notifications.md) Section 5.1 — selection_changed data structure

## Estimated Time: ~2 hours
