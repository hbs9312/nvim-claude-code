# Phase 1-06: Accept/Reject Keymaps, Blocking Response

## Status: ✅ Complete

## Purpose

Set up Accept/Reject keymaps in the diff view and hold the `tools/call` response in a blocking manner until the user makes a decision. On Accept, the proposed changes are saved to the file and a `FILE_SAVED` response is sent. On Reject, the original is preserved and a `DIFF_REJECTED` response is sent.

## Dependencies

- [x] Phase 0: Foundation Infrastructure (complete)
- [ ] Phase 1-01: Tool Registration System (required, incomplete)
- [ ] Phase 1-04: Create Scratch Buffers for Diff (required, incomplete)
- [ ] Phase 1-05: vsplit Layout (required, incomplete)

## Input

User key input:
- `<CR>` or `ga` → Accept
- `q` or `gx` → Reject

## Output

- **Accept**: `{ content: [{ type: "text", text: "FILE_SAVED" }] }` + write proposed changes to file
- **Reject**: `{ content: [{ type: "text", text: "DIFF_REJECTED" }] }` + preserve original

## Implementation Plan

### File: `lua/claude-code/diff.lua` (extending existing)

1. **Hold response with callback pattern**
   ```lua
   -- Save callback in openDiff handler
   function M.open_diff(args, callback)
     -- ... buffer creation, layout setup ...
     session.callback = callback  -- Hold response
     -- MCP response is not sent until callback is invoked
   end
   ```

2. **Accept handling**
   ```lua
   local function accept(session)
     -- Write proposed changes to the original file
     local lines = vim.split(session.new_file_contents, "\n", { plain = true })
     vim.fn.writefile(lines, session.new_file_path)

     -- Refresh any already-open buffer
     local existing_buf = vim.fn.bufnr(session.new_file_path)
     if existing_buf ~= -1 then
       vim.api.nvim_buf_call(existing_buf, function()
         vim.cmd("edit!")  -- Reload from disk
       end)
     end

     -- Send MCP response
     session.callback({
       content = {{ type = "text", text = "FILE_SAVED" }}
     })
   end
   ```

3. **Reject handling**
   ```lua
   local function reject(session)
     -- Preserve original (do nothing)
     -- Send MCP response
     session.callback({
       content = {{ type = "text", text = "DIFF_REJECTED" }}
     })
   end
   ```

4. **Buffer-local keymap setup**
   ```lua
   local function setup_keymaps(session)
     local opts = { buffer = true, nowait = true, silent = true }

     -- Accept keymaps (set on both buffers)
     for _, buf in ipairs({session.old_buf, session.new_buf}) do
       vim.keymap.set("n", "<CR>", function() accept(session) end, { buffer = buf, nowait = true })
       vim.keymap.set("n", "ga",   function() accept(session) end, { buffer = buf, nowait = true })

       -- Reject keymaps
       vim.keymap.set("n", "q",  function() reject(session) end, { buffer = buf, nowait = true })
       vim.keymap.set("n", "gx", function() reject(session) end, { buffer = buf, nowait = true })
     end
   end
   ```

5. **Prevent duplicate calls**
   ```lua
   -- Flag to ensure single execution
   session.resolved = false
   local function resolve(action)
     if session.resolved then return end
     session.resolved = true
     if action == "accept" then accept(session)
     else reject(session) end
     -- cleanup is handled in Phase 1-07
   end
   ```

## Acceptance Criteria

- [ ] `<CR>` key → proposed changes saved to file + `FILE_SAVED` response (DIF-03)
- [ ] `q` key → original preserved + `DIFF_REJECTED` response (DIF-04)
- [ ] `ga` key → Accept action (alternative key)
- [ ] `gx` key → Reject action (alternative key)
- [ ] Keymaps apply only to diff buffers (no effect on other buffers)
- [ ] Duplicate Accept/Reject calls are processed only once
- [ ] After Accept, any already-open buffer is refreshed
- [ ] tools/call response is held until the user makes a decision

## Reference Specs

- [06-diff-ui.md](../06-diff-ui.md) Section 6.5 — Keymap design
- [04-tools.md](../04-tools.md) Section 4.2 — openDiff output (FILE_SAVED / DIFF_REJECTED)
- DIF-03: Accept keymap
- DIF-04: Reject keymap

## Estimated Time: ~2 hours
