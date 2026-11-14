# Feature Specification: Touch ID

**Feature Branch**: `004-touch-id` (the work is done in `main` of the local repo)

**Created**: 2026-10-02

**Status**: In progress — everything except the manual Touch ID check (T009) was done on 2026-10-02

**Input**: The owner wants to confirm each use of a secret with a finger: now, while the keychain
is unlocked, the command gives values without questions. Also, a check of the keychain
status must not open the system password dialog: on 2026-10-02 the tests opened it many times.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Confirmation with a finger (Priority: P1)

**Acceptance Scenarios**:

1. **Given** `secret touchid on`, **When** `get`, `copy`, `run` or `export`, **Then** macOS
   asks for Touch ID (or the Mac password) with a text that tells which secrets and for which command.
2. **Given** the confirmation was less than 300 s ago, **Then** there is no new question. The time
   is set with `secret touchid grace N`, `0` — ask every time.
3. **Given** a refusal or a cancel, **Then** the command exits with an error, the value is not read.
4. **Given** `touchid off` (the default), **Then** the command works as before.
5. **When** `secret touchid off` or `grace` with Touch ID on, **Then** a fresh confirmation is needed.
6. **When** `secret touchid status`, **Then** it shows `on`/`off`, the time and whether the helper is built.

### User Story 2 - Keychain status without a dialog (Priority: P1)

**Acceptance Scenarios**:

1. **Given** the helper is built and the keychain is locked, **When** any command, **Then** the system
   dialog `security wants to use the keychain` does not appear: the command asks for the password itself
   (terminal or its own dialog), or with `SECRET_NO_DIALOG=1` exits with an error.

### Edge Cases

- Touch ID is on, but the helper is not built: the command exits with an error and does not skip the check.
- On a Mac without Touch ID, the helper asks for the Mac password.
- The agent changes the config or the timestamp file around the command: the Claude Code hook blocks such commands.

## Requirements *(mandatory)*

- **FR-001**: `helper/secret-auth.swift`: `auth REASON` (LocalAuthentication, `deviceOwnerAuthentication`) and `status KEYCHAIN` (`SecKeychainGetStatus`).
- **FR-002**: `install.sh` builds the helper into `build/secret-auth` with `swiftc`; without `swiftc` — a warning.
- **FR-003**: `secret touchid on|off|status|grace N`; config `~/.config/secret/config` (`touchid=`, `touchid_grace=`), mode 600.
- **FR-004**: The timestamp of the last confirmation is the file `~/.local/state/secret/touchid-ok`, mode 600.
- **FR-005**: The replacement of the helper, the config and the timestamp (`SECRET_AUTH_HELPER`, `SECRET_CONFIG`, `SECRET_AUTH_STAMP`) and of the clipboard works only with a keychain whose inode differs from the inode of the default keychain.
- **FR-006**: `is_unlocked` through `secret-auth status`, if the helper is built.
- **FR-007**: The hook blocks `secret touchid off|grace`, any mention of `.config/secret/` and `touchid-ok`, the variables `SECRET_AUTH_HELPER=`, `SECRET_CONFIG=`, `SECRET_AUTH_STAMP=`.

## Success Criteria *(mandatory)*

- **SC-001**: With a helper stub, the tests check: there is a question with `on`, none with `off`, a refusal stops the command, grace works.
- **SC-002**: A test locks a temporary keychain and checks the commands on it; the system dialog does not appear (manual check on the first run).
- **SC-003**: Touch ID on the owner's Mac: `get` with a confirmation and with a refusal (manual check).

## Assumptions

- Touch ID protects the `secret` command. A process that calls `security` directly goes
  around it: `/usr/bin/security` creates the items, and it reads them without questions while the keychain
  is unlocked. The hook stops the typical such commands of the agent (feature 001).
- Any process of the user can fake the timestamp. This limit is written in the README.
