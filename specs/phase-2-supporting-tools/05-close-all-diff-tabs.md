# Phase 2-05: closeAllDiffTabs Tool

## Status: ✅ Complete

## Purpose

An MCP tool that closes all currently open diff windows/buffers. Used by Claude to clean up after completing batch modifications or to clear existing diffs before starting a new modification session.

## Dependencies

- [x] Phase 0: Foundation Infrastructure (complete)
- [ ] Phase 1: Core Tools (required, incomplete)
  - Needs to be registered in Phase 1-01 tool-registry (`tools/init.lua`)
  - Requires diff session tracking list from Phase 1's diff implementation (`diff.lua`)

## Input

None. Called without parameters.

## Output

```json
{ "content": [{ "type": "text", "text": "closed N diff tabs" }] }
```

`N` is the actual number of diff sessions closed.

## Implementation Plan

### File Location

`lua/claude-code/tools/documents.lua` or a separate `lua/claude-code/tools/diff_tools.lua`

### Implementation Steps

1. **Tool registration**: Register `closeAllDiffTabs` in the tool-registry (MCP internal tool)
2. **Query diff sessions**: Reference the active diff session list managed by Phase 1's `diff.lua`
3. **Batch cleanup**: Perform cleanup for each active diff session
   - Close diff windows
   - Delete temporary buffers
   - Disable diff mode
4. **Return count**: Return the number of closed diffs as a string

### Pseudocode

```lua
local diff = require("claude-code.diff")

local function close_all_diff_tabs()
  local active_diffs = diff.get_active_sessions()
  local count = #active_diffs

  for _, session in ipairs(active_diffs) do
    diff.cleanup(session)
  end

  return "closed " .. count .. " diff tabs"
end
```

### Integration with diff.lua

- `diff.lua` needs a `get_active_sessions()` function: returns the list of currently active diff sessions
- Reuses the existing `cleanup()` function from `diff.lua`: cleans up individual diff sessions
- Diff session tracking: sessions are registered on `openDiff` calls and removed on accept/reject/close

### Notes

- Already-closed diff sessions (those without pending responses) are ignored
- If there are blocking openDiff calls in progress, they are rejected before closing (sends DIFF_REJECTED response)
- Calling when no diffs exist returns `"closed 0 diff tabs"` without error

## Acceptance Criteria

- [ ] All active diff windows are closed
- [ ] The count of closed diffs is accurate
- [ ] Returns `"closed 0 diff tabs"` when no diffs exist (no error)
- [ ] DIFF_REJECTED response is sent for blocking openDiff calls in progress
- [ ] No diff-related temporary buffers remain after cleanup
- [ ] `closeAllDiffTabs` is registered in the `tools/list` response

## Reference Specs

- [04-tools.md section 4.11](../04-tools.md) - closeAllDiffTabs tool spec
- [06-diff-ui.md](../06-diff-ui.md) - Diff UI design (cleanup logic)
- [07-plugin-api.md section 7.6](../07-plugin-api.md) - Module structure

## Estimated Time: ~1 hour
