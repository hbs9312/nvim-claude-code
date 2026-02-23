# Phase 3-08: README, vimdoc

## Status: Pending

## Purpose

Write user documentation. Provide installation/configuration/usage instructions via the project README.md, and create a vimdoc help file so that all commands, options, and APIs can be looked up within Neovim via `:help claude-code`.

## Dependencies

- [x] Phase 0: Foundation Infrastructure (Complete)
- [ ] Phase 1: Core Tools (Required, Incomplete)
- [ ] Phase 2: Auxiliary Tools (Required, Incomplete) - begin after all features are finalized

## Input

- Complete feature list
- Public API (`require("claude-code")` module)
- User configuration options (`setup()` arguments)
- Command list (`:ClaudeCode`, etc.)

## Output

- `README.md`: User documentation at the project root
- `doc/claude-code.txt`: Neovim help file in vimdoc format

## Implementation Plan

1. **Write README.md**
   - Project introduction and screenshots/GIFs
   - Requirements (Neovim version, Claude Code CLI)
   - Installation instructions (lazy.nvim, packer.nvim, etc.)
   - Basic configuration example (`setup()` call)
   - Full configuration options table
   - Command list and usage
   - Public API reference
   - lualine integration example
   - User autocmd usage examples
   - FAQ / Troubleshooting

2. **Write doc/claude-code.txt (vimdoc)**
   - `:help claude-code` entry point
   - `:help claude-code-setup` - configuration options details
   - `:help claude-code-commands` - command list
   - `:help claude-code-api` - Lua API reference
   - `:help claude-code-events` - User autocmd events
   - `:help claude-code-diff` - diff keymaps and workflow
   - `:help claude-code-statusline` - statusline integration
   - Follow standard vimdoc format (`*tag*`, `>lua` code blocks, etc.)

3. **Verify documentation accuracy**
   - Confirm all commands, options, and APIs are fully documented
   - Verify that code examples actually work
   - Confirm `:helptags` generation

## Verification Criteria

- [ ] `:help claude-code` works correctly
- [ ] No errors when running `:helptags doc/`
- [ ] README.md includes installation, configuration, commands, and API
- [ ] vimdoc documents all commands, options, and APIs
- [ ] Code examples match the actual configuration/API
- [ ] vimdoc format follows standards (see `:help help-writing`)

## Reference Specs

- `07-plugin-api.md` (entire document)

## Estimated Time: ~3 hours
