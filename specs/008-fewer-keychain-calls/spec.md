# Feature Specification: Fewer keychain calls

**Feature Branch**: `008-fewer-keychain-calls` (the work is done in `main` of the local repo)

**Created**: 2026-10-02

**Status**: Done — 2026-10-02

**Input**: The owner asked to remove extra `security` calls. Measurement of 2026-10-02 on a temporary
keychain (`tests/bench.sh`, `N=300`):

| Command | 40 items | 300 items |
|---|---|---|
| `import` of all values | 4.1 s | 33.8 s |
| `check` .env on all keys | 0.8 s | 6.1 s |
| `ls -l` | 0.11 s | 0.44 s |
| `run` with 5 references | 0.22 s | 0.22 s |
| `set` of one value | 0.12 s | 0.17 s |
| `get` | 0.08 s | 0.13 s |

`import` grows as n²: after each write, `refresh_names` reads the whole keychain. `check`
calls `security` two times for each key: existence and expiry.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Fast import and check (Priority: P1)

**Acceptance Scenarios**:

1. **Given** 300 items, **When** `import` of 300 values, **Then** the time grows linearly: no more than 15 s.
2. **Given** 300 items, **When** `check` on 300 keys, **Then** no more than 1 s.
3. **Then** the other commands are not slower than in the table.

## Requirements *(mandatory)*

- **FR-001**: The command reads the attributes of all items (name, comment, expiry) with one `dump-keychain` and keeps them in memory until the first write to the keychain.
- **FR-002**: `import`, `restore`, the migration in `touchid on/off` and `__rehelper` update the name cache once at the end.
- **FR-003**: The check after a write (`item_exists` in `set`) is a direct query, without reading the whole keychain.

## Success Criteria *(mandatory)*

- **SC-001**: The measurement on 300 items before and after is written in `tasks.md`.
- **SC-002**: `tests/run.sh` passes in full.
