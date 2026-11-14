# Feature Specification: Move secrets out of project .env files

**Feature Branch**: `013-env-sweep`. The work goes on in `main` of the local repository.

**Created**: 2026-10-07

**Status**: In progress

**Input**: The owner asked to find `.env` and similar files on the computer and move the secrets into
the store, with comments that an agent can understand. In the files, replace the values with references
`secret:NAME`. Move and delete the old copy `.env.*.bak` of one project.

## User Scenarios & Testing *(mandatory)*

<!-- utr-100: 8.2 — the heading is set by the spec-kit template -->
### User Story 1 - Selective move (Priority: P1)

1. **When** `secret import -p PREFIX --keys K1,K2 FILE`, **Then** the command moves only these
   keys. The other lines stay as they are.
2. **When** `--ref KEY=NAME`, **Then** the line KEY becomes a reference to the existing secret NAME.
3. **Given** a key from `--keys` or `--ref` is not in the file, **Then** error, the file does not change.

<!-- utr-100: 8.2 — the heading is set by the spec-kit template -->
### User Story 2 - Parse errors without values (Priority: P1)

1. **When** a line has no `=` or has an incorrect name, **Then** the error gives the line number. The text
   of the line does not go into the message.

## Requirements *(mandatory)*

<!-- utr-100: 1.9 — the IDs are set by the spec-kit template -->
- **FR-001**: `import --keys`, `import --ref`.
- **FR-002**: `parse_line` writes the line number instead of the text.
- **FR-003**: `is_test_kc` compares paths if the working keychain file does not exist.
- **FR-004**: Move: a comparison inside `secret run` finds duplicates, with no output of values.

## Success Criteria *(mandatory)*

<!-- utr-100: 1.9 — the IDs are set by the spec-kit template -->
- **SC-001**: The tests `013:` pass.
- **SC-002**: After the move, `secret check` on each file shows only `ok` for secrets.
