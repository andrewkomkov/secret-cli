# Feature Specification: Daily convenience

**Feature Branch**: `002-daily-use` (the work is done in `main` of the local repo)

**Created**: 2026-10-02

**Status**: In progress — everything except the manual Tab check (T012) was done on 2026-10-02

**Input**: The owner wants to paste a password by hand quickly, complete names with Tab,
rename secrets and see the tokens that expire soon.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Password to the clipboard (Priority: P1)

The owner needs to paste a password into a login form. He copies it with one command. After 30
seconds the clipboard is cleared.

**Acceptance Scenarios**:

1. **When** `secret copy NAME`, **Then** the value is in the clipboard, the output is `copied: NAME (clears in 30s)`, the output has no value.
2. **Given** 30 s passed and the clipboard has the same value, **Then** the clipboard is empty.
3. **Given** the owner copied other text within the 30 s, **Then** that text stays.
4. **When** `secret copy NAME 5`, **Then** the clipboard is cleared after 5 s.

### User Story 2 - Names with Tab (Priority: P2)

**Acceptance Scenarios**:

1. **When** `secret <Tab>` in zsh, **Then** the list of commands.
2. **When** `secret run --mask CH_EX<Tab>`, **Then** the secret names with this prefix.
3. **Given** the keychain is locked, **When** Tab, **Then** the names come from the cache, the password dialog does not open.

### User Story 3 - Rename (Priority: P2)

**Acceptance Scenarios**:

1. **When** `secret mv OLD NEW`, **Then** NEW has the value, comment and expiry of OLD, OLD is deleted.
2. **Given** NEW exists, **Then** an error, both items stay unchanged. With `-f` NEW is replaced.
3. **Then** the output reminds you to update the `secret:OLD` references.

### User Story 4 - Expiry (Priority: P2)

**Acceptance Scenarios**:

1. **When** `secret set -x 2026-12-31 NAME` or `secret expire NAME 2026-12-31`, **Then** the expiry is saved; `secret expire NAME none` removes it.
2. **When** `secret ls --expiring [DAYS]` (default 30), **Then** a list of the expired secrets and of those that expire within DAYS days, with the date.
3. **Given** a secret has expired, **When** `run` or `check` uses it, **Then** a warning goes to stderr, the command works.
4. **When** `secret ls -l`, **Then** a secret with an expiry shows the date.

### Edge Cases

- A wrong date (`2026-13-01`) — an error.
- `copy` in an environment without a clipboard (no `pbcopy`) — an error.
- The name cache is missing — Tab offers nothing, no error.

## Requirements *(mandatory)*

- **FR-001**: `secret copy NAME [SECONDS]`, default 30; the background process keeps only a hash of the value.
- **FR-002**: `copy` writes a line to the access log.
- **FR-003**: The file `completions/_secret` for zsh; `install.sh` puts it into `$ZSH_CUSTOM/completions`.
- **FR-004**: The name cache `~/.local/state/secret/names` (mode 600) is updated after `ls`, `set`, `gen`, `rm`, `mv`.
- **FR-005**: `secret mv [-f] OLD NEW`.
- **FR-006**: The expiry is kept in the `gena` attribute of the item as `expires=YYYY-MM-DD`; `set -x DATE`, `secret expire NAME DATE|none`.
- **FR-007**: `secret ls --expiring [DAYS]`; a warning in `run` and `check`.

## Success Criteria *(mandatory)*

- **SC-001**: The output of `copy` and the name cache have no values (test).
- **SC-002**: `tests/run.sh` passes in full and does not touch the owner's clipboard.

## Assumptions

- Clipboard managers (Raycast, Alfred) can keep the copied value in their history.
  `pbcopy` cannot mark the item as concealed (`org.nspasteboard.ConcealedType`). This is written in the README.
- Secret names are not considered secret: they can be kept in a cache.
