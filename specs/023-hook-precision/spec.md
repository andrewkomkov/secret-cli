# Feature Specification: a hook without false positives

**Feature Branch**: `023-hook-precision`. The work goes on in `main`.

**Created**: 2026-10-22

**Status**: Done 2026-10-22

**Input**: The owner: "fix the hooks where necessary, so that I can work well with the new version". On 2026-10-22 the hook
stopped safe commands of the agent three times:

- heredoc `cat > spec.md` with the text "`secret touchid repair`" inside.
- `codesign --verify` for the store helper.
- An edit of `tests/run.sh` with the names of test variables in the text.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Text to a file (Priority: P1)

1. **When** the agent writes text through `cat > FILE <<EOF`, `tee FILE <<EOF` or `git commit -F - <<EOF`,
   **Then** the hook does not check the heredoc body.
2. **When** the heredoc body goes to `sh`, `bash`, `zsh` or another program, **Then** the hook checks
   the body as commands.

### User Story 2 - Check of the helper without a run (Priority: P1)

1. **When** a command only looks at the helper file (`codesign`, `ls`, `stat`, `file`, `shasum`,
   `xattr`, `spctl`), **Then** the hook lets it through.
2. **When** the same part of the command has `$(` or a backquote, **Then** the hook blocks it,
   as before.
3. The hook blocks a run of the helper under any name, as before.

## Requirements *(mandatory)*

- **FR-001**: the hook cuts out the heredoc body for `cat`, `tee`, `git` before the check.
- **FR-002**: the store helper rule lets through the parts of a command that start with a program
  from the read list.
- **FR-003**: all previous `hook blocks` checks pass.

## Success Criteria *(mandatory)*

- **SC-001**: the three commands from Input pass the hook.
- **SC-002**: `tests/run.sh` passes in full.
