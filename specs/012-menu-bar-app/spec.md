# Feature Specification: SecretBar menu bar app

**Feature Branch**: `012-menu-bar-app`. The work is done in `main` of the local repository.

**Created**: 2026-10-07

**Status**: In progress

**Input**: The owner asked for an app with an interface: "everything, so that it is a really
premium app", and an access log, the last 20 entries.

## User Scenarios & Testing *(mandatory)*

<!-- ste: E8.2 — the spec-kit template sets these headings -->
### User Story 1 - State and lock (Priority: P1)

1. **Given** grace is active, **Then** the menu bar icon is an open lock. The window shows how
   much time remains.
2. **When** "Lock" is clicked, **Then** grace ends, the icon is a closed lock.
3. **Given** the profile of the helper expires in less than 2 days, or a secret has expired,
   **Then** the icon shows a warning.

### User Story 2 - Secrets (Priority: P1)

1. **When** the window is open, **Then** a list of names, comments and expiry dates without
   Touch ID, search by name and comment.
2. **When** "Copy" is clicked, **Then** the value is in the clipboard, cleared after 30 seconds.
   Touch ID is necessary if grace is closed.
3. **When** "Add" is clicked, **Then** name, comment, expiry, value in a hidden field or
   generation.
4. **When** "Edit", "Rename", "Delete" is clicked, **Then** the app runs the commands
   `secret note`, `expire`, `set`, `mv`, `rm`. The app asks for a separate confirmation for a
   delete.

### User Story 3 - Activity (Priority: P2)

1. **Then** the last 20 lines of the access log: time, agent or human, operation, names.

### User Story 4 - Settings (Priority: P2)

1. Grace time (0, 5, 15, 30, 60 minutes), with Touch ID.
2. The expiry of the helper profile and the "Renew" button.
3. Backup to a file with a password.
4. Launch at login.

### Edge Cases

- The data protection store is off: the app shows the hint `secret migrate`.
- The helper does not start: the app shows an error and the "Renew" button.
- Touch ID is cancelled: the app shows "Cancelled", the clipboard does not change.

## Requirements *(mandatory)*

<!-- ste: E1.9 — the spec-kit template sets the IDs -->
- **FR-001**: The app calls only `bin/secret` and the helper. It has no keychain calls of its
  own.
- **FR-002**: The value goes to the clipboard through `secret copy`. The value does not get into
  the memory of the app. A new value goes to `secret set` through stdin.
- **FR-003**: Ad-hoc signature, hardened runtime, no entitlements.
- **FR-004**: The interface is in Russian. Keyboard: ⌘F, arrows, Enter.
- **FR-005**: `--selftest` checks the parsing of the command output without the interface.

## Success Criteria *(mandatory)*

<!-- ste: E1.9 — the spec-kit template sets the IDs -->
- **SC-001**: Test: `--selftest` passes. The binary has no `SecItem*` calls and no entitlements.
- **SC-002**: Manual check: all actions from US1–US4 on the production store.
