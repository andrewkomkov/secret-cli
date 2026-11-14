# Feature Specification: Encrypted backup

**Feature Branch**: `003-backup` (the work is done in `main` of the local repo)

**Created**: 2026-10-02

**Status**: In progress — everything except the manual check with the dialog (T004) was done on 2026-10-02

**Input**: The owner wants to save all secrets to one file under a separate password and
restore them on another Mac or after the keychain is lost.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Save all secrets to a file (Priority: P1)

**Acceptance Scenarios**:

1. **When** `secret export FILE`, **Then** the command asks for the backup password two times (hidden
   input), writes FILE with mode 600, prints `exported: N secrets to FILE`.
2. **Then** FILE has no value, name or comment in plain text at all.
3. **Given** FILE exists, **Then** an error; with `-f` FILE is replaced.
4. **Given** the password is shorter than 12 characters, **Then** an error.

### User Story 2 - Restore from a file (Priority: P1)

**Acceptance Scenarios**:

1. **When** `secret restore FILE` on an empty keychain, **Then** all secrets are in place with their values,
   comments and expiry dates, the output is `restored: N, skipped: 0`.
2. **Given** a secret with this name exists, **Then** it is skipped; with `-f` it is replaced.
3. **Given** a wrong password or a damaged file, **Then** an error, the keychain does not change.

### Edge Cases

- Empty keychain: `export` writes a file with 0 secrets.
- The backup password and the values do not get to the disk in plain form: neither into temporary files nor into process arguments.

## Requirements *(mandatory)*

- **FR-001**: `secret export [-f] [--pass-stdin] FILE`, `secret restore [-f] [--pass-stdin] FILE`.
- **FR-002**: Encryption `openssl enc -aes-256-cbc -pbkdf2 -iter 600000 -salt` (LibreSSL from macOS).
- **FR-003**: Inside the file — the header `secret-cli-export 1`, the lines `hex(name) hex(value) hex(comment) hex(expiry)` and a sha256 checksum of the lines. `restore` checks the header and the checksum before the first write to the keychain.
- **FR-004**: The backup password goes to `openssl` through a file descriptor (`-pass fd:3`), not through an argument and not through an environment variable.
- **FR-005**: `--pass-stdin` reads the password from the first line of stdin: for tests and automation.
- **FR-006**: `export` and `restore` write a line to the access log (no names: only the number of secrets).

## Success Criteria *(mandatory)*

- **SC-001**: export → restore into a new keychain gives the same names, values, comments and expiry dates (test).
- **SC-002**: `grep` of any value, name and comment in the backup file is empty (test).
- **SC-003**: `tests/run.sh` passes in full.

## Assumptions

- `openssl enc` does not give authenticated encryption. Integrity is checked by a sha256 inside
  the encrypted data: a wrong password or a changed file gives an error.
- The owner keeps the backup password apart from the backup (not in the same keychain).
