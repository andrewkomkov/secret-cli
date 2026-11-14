# Feature Specification: public repository and install through Homebrew

**Feature Branch**: `022-public-brew`. The work goes on in `main`.

**Created**: 2026-10-22

**Status**: Done 2026-10-22

**Input**: The owner: "our software must be in a public repository and install through brew".
The owner required to remove all mentions of the employer from the repository and the history. Delete the old history,
keep one commit in the public repository.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Install with one command (Priority: P1)

1. **When** a human runs `brew install andrewkomkov/secret/secret`, **Then** Homebrew installs
   the `secret` command and the zsh completion. Then Homebrew builds the Touch ID helper and the helper
   of the Secure Enclave store.
2. `brew upgrade` installs a new version. If the store helper changed and its signature is ad-hoc,
   the command asks for one touch of `secret touchid repair`.
3. The human installs SecretBar and the Claude Code hook: `$(brew --prefix secret)/libexec/install.sh
   --app --claude-hook`. SecretBar needs Xcode.

### User Story 2 - Public repository without personal data (Priority: P1)

1. The files and the history have no name of the employer, no names of its projects, no personal paths and no secret names
   of the owner.
2. The history starts with one commit, the author is the personal address of the owner.
3. The full old history is only on the owner's Mac, in a bundle file.

## Requirements *(mandatory)*

- **FR-001**: public repository `github.com/andrewkomkov/secret-cli`, MIT license.
- **FR-002**: tap `github.com/andrewkomkov/homebrew-secret`, formula `secret`, build from the source of
  the tag.
- **FR-003**: SecretBar searches for references `secret:NAME` in the directory from the `projectsDir` setting, by
  default in the home directory.
- **FR-004**: demo data, tests and documents use fictional projects.

## Success Criteria *(mandatory)*

- **SC-001**: on a clean prefix, `brew install` and `brew test` pass.
- **SC-002**: a search of the repository and the history finds no words from the deny list.
- **SC-003**: `tests/run.sh` passes in full.

## Assumptions

- The brew user works on macOS with the Command Line Tools: Homebrew does not work without them.
- The user usually has no Apple Development certificate. Then the helper gets an ad-hoc signature.
