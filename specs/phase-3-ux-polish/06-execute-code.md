# Phase 3-06: executeCode Tool (Optional)

## Status: Pending

## Purpose

Provide a code execution tool. In the VS Code extension, code is executed through a Jupyter kernel; in Neovim, this can be implemented via an alternative method or optionally left unimplemented.

## Dependencies

- [x] Phase 0: Foundation Infrastructure (Complete)
- [ ] Phase 1: Core Tools (Required, Incomplete) - especially 01 tool-registry
- [ ] Phase 2: Auxiliary Tools (Required, Incomplete)

## Input

- `code` (string): code to execute
- Tool call parameters:
  ```json
  {
    "code": "print('hello world')"
  }
  ```

## Output

- Execution result (stdout/stderr)
  ```json
  {
    "output": "hello world\n",
    "error": ""
  }
  ```

## Implementation Plan

Choose one of three implementation options:

### Option 1: Not Implemented (Simplest)

- Do not register `executeCode` tool in the tool-registry
- Claude Code client cannot use this tool
- The safest and simplest choice

### Option 2: External Process Execution via vim.system()

- Execute code in an external process using `vim.system()`
- Use language detection or a user-specified interpreter
- Prevent infinite execution with timeout settings
  ```lua
  local result = vim.system(
    { "python3", "-c", code },
    { timeout = 10000 }
  ):wait()
  ```

### Option 3: Execute in Neovim Terminal + Capture Output

- Execute code in a new terminal buffer
- Capture terminal output and return as result
- Users can visually observe the execution process

### Common Considerations

- Security: risks of arbitrary code execution, consider user confirmation prompts
- Timeout: execution time limits to prevent infinite loops, etc.
- Sandboxing: whether to restrict file system access

## Verification Criteria

- [ ] (Option 1) Tool is not registered and unavailable in Claude Code
- [ ] (Option 2/3) stdout result is returned after code execution
- [ ] (Option 2/3) stderr result is returned
- [ ] (Option 2/3) Appropriate error message returned on timeout
- [ ] (Option 2/3) Security warning or user confirmation works

## Reference Specs

- `04-tools.md` Section 4.13

## Estimated Time: ~2 hours (if implemented)
