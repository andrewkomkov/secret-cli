# Feature Specification: Metadata items without Touch ID

**Feature Branch**: `011-meta-items`. The work is done in `main` of the local repository.

**Created**: 2026-10-07

**Status**: Complete — 2026-10-07, the production store is converted (T008)

**Input**: The owner touched the sensor 3 times for one command. The system log `coreauthd`
showed the cause. Before each command, `bin/secret` calls `policy show` and `list`. These calls
read the attributes of items under `.userPresence`, and the keychain asks for Touch ID for the
attributes too.

## User Scenarios & Testing *(mandatory)*

<!-- ste: E8.2 — the spec-kit template sets this heading -->
### User Story 1 - One touch per grace (Priority: P1)

**Independent Test**: the test build writes each access to an item with a value to a log.
Commands other than reading a value make no such access.

**Acceptance Scenarios**:

1. **When** `ls`, `ls -l`, `has`, `check`, `note`, `expire`, `set`, `rm`, `touchid status` run,
   **Then** Touch ID is not necessary.
2. **When** the first read of a value in grace occurs, **Then** there is one Touch ID window for
   all items.
3. **When** the next reads in grace occur, **Then** there are no windows.

### Edge Cases

- A store from feature 009 without metadata items: `secret __reindex` creates them, one Touch ID
  window.
- The metadata item exists, the item with the value does not: a read gives `not found`.

## Requirements *(mandatory)*

<!-- ste: E1.9 — the spec-kit template sets the requirement IDs -->
- **FR-001**: Each secret has a metadata item: account `secret-cli.meta`, name, comment,
  expiry, without `.userPresence`.
- **FR-002**: `list`, `has`, `attrs`, `policy show` work only with metadata items.
- **FR-003**: Only the agent reads the items with values. The agent finds a change of an item
  from the dates of the metadata item.
- **FR-004**: The check before a command is `ping`, without the keychain.
- **FR-005**: The agent log `~/.local/state/secret/agent.log`: Touch ID windows, system windows,
  no values.

## Success Criteria *(mandatory)*

<!-- ste: E1.9 — the spec-kit template sets the criteria IDs -->
- **SC-001**: Test: only the agent accesses the items with values.
- **SC-002**: Manual check. `ls`, `ls -l`, `has`, `touchid status` open no windows. Two `run` in
  a row open one window.
