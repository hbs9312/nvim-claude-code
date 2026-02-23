# Phase 3-05: Multi-Workspace

## Status: ✅ Complete

## Purpose

Support multiple workspace folders by integrating with `vim.lsp.buf.list_workspace_folders()` and providing multi-folder information to the Claude Code client.

## Dependencies

- [x] Phase 0: Foundation Infrastructure (Complete)
- [ ] Phase 1: Core Tools (Required, Incomplete)
- [ ] Phase 2: Auxiliary Tools (Required, Incomplete) - especially 02 getWorkspaceFolders

## Input

- LSP workspace folder list (`vim.lsp.buf.list_workspace_folders()`)
- Workspace folders manually added by the user

## Output

- Multiple workspace folders recorded in the lock file
- Full folder list included in `getWorkspaceFolders` tool response

## Implementation Plan

1. **Extend lock file structure**
   - Support `workspaceFolders` array instead of a single `workspaceFolder`
   ```json
   {
     "workspaceFolders": [
       "/path/to/project",
       "/path/to/library"
     ]
   }
   ```

2. **LSP workspace folder integration**
   - Query folder list from `vim.lsp.buf.list_workspace_folders()`
   - Fall back to `vim.fn.getcwd()` when no LSP server is available

3. **Workspace folder change detection**
   - Detect folder changes via `LspAttach`, `LspDetach` autocmds
   - Automatically update the lock file on changes
   - Reflect the latest list in the `getWorkspaceFolders` response

4. **Update getWorkspaceFolders tool**
   - Modify to return multiple folders as an array
   ```lua
   return {
     workspaceFolders = get_workspace_folders(),
   }
   ```

## Verification Criteria

- [ ] Multiple workspace folders are included in the `getWorkspaceFolders` response
- [ ] Multiple folders are recorded as a `workspaceFolders` array in the lock file
- [ ] Automatically updates when LSP workspace folders change
- [ ] Works based on cwd in environments without LSP
- [ ] Works correctly in single-folder environments (backward compatible)

## Reference Specs

- `02-connection.md` Section 2.2 (`workspaceFolders`)

## Estimated Time: ~2 hours
