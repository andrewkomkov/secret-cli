# Feature Specification: a secret in GitHub Actions

**Feature Branch**: `021-github-actions-secrets`. The work goes on in `main`.

**Created**: 2026-10-22

**Status**: In progress

**Input**: The owner: "so that our software works with GitHub secrets". GitHub Actions secrets
accept a value and do not give it back. The owner selected the send of the value from `secret` to GitHub.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Send a secret to a repository (Priority: P1)

1. **When** a human or an agent runs `secret gh NAME -R owner/repo`, **Then** a macOS window
   asks for confirmation. After "Send", the command writes the value of NAME to the Actions secret
   `NAME` of this repository.
2. `secret gh NAME GH_NAME ...` gives the secret a different name in GitHub.
3. The command passes the flags `-e ENV`, `-o ORG`, `-v VISIBILITY`, `-a APP` to `gh` without changes.
4. The output and the log contain the names and the target, they contain no values.

### User Story 2 - No send without confirmation (Priority: P1)

1. **When** the human clicks "Cancel" or the window is closed for the command (`SECRET_NO_DIALOG=1`),
   **Then** the command gives an error. It does not call `gh`.
2. The command rejects the flags `-b`, `--body`, `-f`, `--env-file`: the value comes only from NAME.

### Edge Cases

- No `gh`: error "gh not found" with a hint.
- No NAME: error "not found".
- GH_NAME with a dot or a hyphen: error, GitHub does not accept such names.

## Requirements *(mandatory)*

- **FR-001**: `secret gh NAME [GH_NAME] [gh flags]` calls `gh secret set GH_NAME [flags]`,
  the value goes through stdin.
- **FR-002**: before the send, a human confirms it in the window.
- **FR-003**: the access log writes the operation `gh`, the name, the target.
- **FR-004**: the Claude Code hook blocks the test variables `SECRET_GH` and `SECRET_CONFIRM`.

## Success Criteria *(mandatory)*

- **SC-001**: a secret gets into Actions secrets with one command and one confirmation.
- **SC-002**: the value does not appear in the output, the log, `argv` and the text of the window.

## Assumptions

- `gh` is installed, and the human ran `gh auth login`.
