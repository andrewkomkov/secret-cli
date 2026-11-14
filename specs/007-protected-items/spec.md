# Feature Specification: Items that only the helper reads

**Feature Branch**: `007-protected-items` (the work is done in `main` of the local repo)

**Created**: 2026-10-02

**Status**: In progress — everything except the manual check on the owner's keychain (T014) was done on 2026-10-02

**Input**: Now Touch ID protects only the `secret` command: while the keychain is unlocked,
`/usr/bin/security` reads the items without questions. The owner wants that nobody can read a
value without Touch ID.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A value is read only after Touch ID (Priority: P1)

**Acceptance Scenarios**:

1. **Given** `secret touchid on`, **Then** all items go into protected mode: their creator
   and the only trusted reader is the helper.
2. **When** any process calls `security find-generic-password -w` for such an item,
   **Then** macOS shows a dialog with a request. Without a human, the value is not read.
3. **When** `get`, `copy`, `run`, `export`, **Then** the helper asks for Touch ID (or takes
   the confirmation from the grace window) and only then reads the values.
4. **When** a binary with another signature (rebuilt, changed, foreign) reads an item, **Then** a refusal.
5. **Given** an item was replaced (deleted and created again by another process), **Then** the read
   exits with the error `not protected` and does not give the replaced value.

### User Story 2 - Helper update (Priority: P1)

**Acceptance Scenarios**:

1. **Given** the helper code changed, **When** `./install.sh`, **Then** the new helper is built
   next to the old one. The old one reads all items (one Touch ID), the new one writes them, the values are compared,
   then the new one replaces the old one.
2. **Given** the helper code did not change, **Then** there is no rebuild.
3. **Given** the migration failed, **Then** the old helper stays, the items are in place.

### User Story 3 - Turning off (Priority: P2)

1. **When** `secret touchid off`, **Then** after Touch ID the items go back to normal mode
   (creator `security`), the policy and the grace stamp are deleted.

### Edge Cases

- The policy (`__secret-cli.policy`) was deleted: the helper takes grace as 0 and asks for Touch ID every time.
- The grace stamp was faked: the helper checks the HMAC of the stamp with the key from the policy, a fake does not pass.
- The migration stopped between steps: the item `NAME#new` stays, the next migration finishes it.
- The helper is not built, but the items are protected: the read exits with an error and the hint `./install.sh`.

## Requirements *(mandatory)*

- **FR-001**: Helper: `status`, `auth`, `read`, `write`, `delete`, `policy`; the keychain UI is off.
- **FR-002**: `read KC REASON NAME...` prints `hex(value)`, one line per name. Touch ID is inside the helper. An item that the helper did not create is the error `not protected: NAME`.
- **FR-003**: `write KC NAME [--comment C] [--expiry D] [--keep-attrs]`, the value from stdin. A foreign item is replaced like this: `NAME#new` → delete the old one → rename.
- **FR-004**: The policy is the item `__secret-cli.policy` that the helper created: grace and a random HMAC key. The grace stamp is the file `~/.local/state/secret/touchid-ok`: time and HMAC.
- **FR-005**: An ad-hoc build with hardened runtime (`codesign -s - -o runtime`). The hash of the source is kept in `build/secret-auth.src-sha256`. If it changed — migration (US2).
- **FR-006**: The test helper is built with `-D SECRET_TEST`: the Touch ID answer comes from a file. The production helper has no such code.
- **FR-007**: `bin/secret`: in protected mode, values are read and written only through the helper. `ls`, `has`, `check` read the attributes through `security` without `-w`. The items `__secret-cli.*` are not shown in `ls`.
- **FR-008**: Without the helper and in normal mode, the command works as before.

## Success Criteria *(mandatory)*

- **SC-001**: Test: another binary cannot read a protected item (an error code, no dialog).
- **SC-002**: Test: the migration old → new helper keeps all values, comments and expiry dates.
- **SC-003**: Test: a replaced item gives `not protected`.
- **SC-004**: Manual check on the owner's keychain: after `touchid on`, the command `security find-generic-password -w` shows a dialog, a read through `secret` asks for Touch ID.

## Assumptions

- The comment, the expiry and the existence of the item itself are protected worse than the value: any process of the user can change or delete them (research R6, R7).
- While `secret run` goes on, the values are in the environment of the child process. Processes of the same user see it (`ps -E`). This is a property of passing through the environment.
- A `security wants to access` dialog for protected items that appeared without `secret` is a sign of a read around it. The answer is Deny.
