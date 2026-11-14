# Feature Specification: Data protection keychain store

**Feature Branch**: `009-data-protection-store`. The work goes on in `main` of the local repo.

**Created**: 2026-10-07

**Status**: Complete — 2026-10-07, the working secrets are moved (T025)

<!-- ste: E8.7 — macOS version number -->
**Input**: The helper and the command work on the file keychain through the `SecKeychain*` API.
In macOS 10.10, Apple marked this API as deprecated. `swiftc` gives 26 warnings. The owner wants
to move to the current store: the data protection keychain. There is no paid developer account,
and there will be none. A probe on 2026-10-07 showed that the free Personal Team in Xcode gives
access to this store (research R1–R8).

## User Scenarios & Testing *(mandatory)*

<!-- ste: E8.2 — heading set by the spec-kit template -->
### User Story 1 - Secrets in the new store (Priority: P1)

The owner moves all secrets to the data protection keychain and continues to use the same commands.

**Why this priority**: this is the goal of the feature: leave the deprecated API.

**Independent Test**: on the test build of the helper: `migrate` moves the items, then `get`,
`run`, `ls -l`, `check` give the same results as before the move.

**Acceptance Scenarios**:

1. **Given** the store helper is built and the file keychain has items, **When**
   `secret migrate --backup FILE`, **Then** the command first makes an encrypted copy in `FILE`.
   It is a copy of the same type that `export` makes. Then the command copies all items with
   comments and expiry dates to the new store. Then the command compares the values and turns on
   the new store.
2. **Given** the new store is on, **When** any command, **Then** it works with the new store.
   These are the commands `set`, `get`, `run`, `ls`, `check`, `import`, `export`, `restore`,
   `mv`, `rm`, `note`, `expire`, `gen`, `ask`, `copy`. References `secret:NAME` in `.env` work
   as before.
3. **Given** the move failed because Touch ID was refused or a write failed, **Then** the new
   store is off. The command does not change the file keychain.
4. **Given** the comparison passed, **Then** `migrate` deletes the moved items from the file
   keychain. The copy in `FILE` is encrypted. The old items in the file keychain do not have the
   new protection. If someone deletes the mode file, the command starts to work with these items.
   The command does not delete the keychain file. The owner deletes it.

---

<!-- ste: E8.2 — heading set by the spec-kit template -->
### User Story 2 - Read a value only after Touch ID (Priority: P1)

**Why this priority**: the Personal Team signature does not protect the value. The profile allows
all access groups of the team, and any process of the user can sign a binary (research R4).

**Independent Test**: manual check. A process with the same signature gets the value only after
Touch ID.

**Acceptance Scenarios**:

1. **When** any process reads a value from the new store, **Then** the system asks for Touch ID
   or the Mac password. If no person is present, the system returns an error. With
   `SECRET_NO_DIALOG=1`, no window opens.
2. **When** `get`, `copy`, `run`, `export`, `mv`, `note`, `expire`, **Then** one command causes
   no more than one Touch ID question. This is the limit for all items of the command.
3. **When** `ls`, `ls -l`, `ls --expiring`, `has`, `check`, **Then** Touch ID is not necessary.
   The command reads names, comments and expiry dates without Touch ID.
4. **When** `set`, `gen`, `import`, `restore`, `rm`, **Then** Touch ID is not necessary. The
   command writes a new value and deletes an item, but it does not read the old value.

---

<!-- ste: E8.2 — heading set by the spec-kit template -->
### User Story 3 - Time without a new question (Priority: P2)

**Why this priority**: the agent calls `secret run` many times in a row. A question on each call
stops the work.

**Independent Test**: on the test build, two `get` in a row with grace 300 give one Touch ID
answer. After `secret lock`, a question again.

**Acceptance Scenarios**:

1. **Given** grace of N seconds, 300 by default, **When** Touch ID is confirmed, **Then** the next
   commands read values without a question. This is in effect for N seconds.
2. **When** `secret lock`, **Then** the command ends grace immediately.
3. **Given** grace 0, **Then** each command asks for Touch ID.
4. **When** `secret touchid grace N`, **Then** a fresh Touch ID is necessary. N greater than 3600
   is an error.
5. **When** `secret touchid status`, **Then** the store, grace and the profile expiry date are shown.

---

<!-- ste: E8.2 — heading set by the spec-kit template -->
### User Story 4 - Profile renewal (Priority: P1)

**Why this priority**: the profile of a free team is valid for 7 days. Without renewal, the helper
stops starting, and the secrets are not available until a rebuild.

**Independent Test**: `install.sh --renew` with a profile date closer than 3 days rebuilds the
helper. If the date is more than 3 days away, the command does nothing.

**Acceptance Scenarios**:

1. **Given** less than 3 days remain until the profile expires, **When** `install.sh --renew`,
   **Then** the command rebuilds the helper with a new profile. The items are available as before.
2. **Given** `install.sh --launchd`, **Then** a LaunchAgent runs `install.sh --renew` once a day
   and at login.
3. **Given** less than 2 days remain until expiry or the profile has expired, **When** any
   `secret` command, **Then** a warning goes to stderr. It contains the renewal command.

---

<!-- ste: E8.2 — heading set by the spec-kit template -->
### User Story 5 - Move back (Priority: P3)

**Acceptance Scenarios**:

1. **When** `secret migrate --back`, **Then** after Touch ID the command copies all items to the
   file keychain with comments and expiry dates. Then the command turns off the new store and
   deletes its items.
2. **Given** the file keychain already has an item with the same name, **Then** the command
   replaces its value with the value from the new store.

### Edge Cases

- The store helper is not built, but the store is on: the command gives an error with the hint
  `./install.sh`.
- The profile has expired, the helper does not start: an error with the hint
  `./install.sh --renew`. The items stay in place. A rebuild keeps the access group.
- The Apple ID session in Xcode has expired: renewal fails. `install.sh --renew` tells the user to
  sign in to Xcode → Settings → Accounts.
- Two processes start the grace agent process at the same time: one works, the second stops.
- The agent process crashed: the next command starts a new agent and asks for Touch ID again.
- `touchid off` in the new store: an error, the protection is always on.
- `unlock` in the new store: does nothing, the store is open while the macOS session is open.
- An item in the new store without `.userPresence`: another process made it. A read gives the
  error `not protected: NAME`. The helper does not give the value.
- The Mac was replaced or restored from a backup: the items are available only on the Mac where
  they were made. A Mac backup does not move them. The recovery path is `secret restore` from the encrypted copy.

## Requirements *(mandatory)*

### Functional Requirements

<!-- ste: E1.9 — FR and US identifiers set by the spec-kit template -->
- **FR-001**: The store helper is a separate app. Xcode builds it from the source in the repo and
  signs it with the owner's Personal Team certificate. Xcode finds the Team ID automatically.
- **FR-002**: Item: account `secret-cli`, service is the name, a comment, expiry `expires=`,
  access only on this Mac with an unlocked session, the value under `.userPresence`.
- **FR-003**: Functions of the helper:
  - list of attributes without Touch ID.
  - presence of an item.
  - read of values with Touch ID, one question per call.
  - batch write from stdin without Touch ID.
  - change of attributes with Touch ID.
  - delete without Touch ID.
  - grace policy.
  - status.
- **FR-004**: Values go between `bin/secret` and the helper through stdin and stdout in hex, not
  through arguments.
- **FR-005**: The agent process of the helper holds grace. It starts at the first read, keeps the
  confirmed context and stops when grace has ended, on `secret lock` or on `touchid grace`. The
  connection to it is a socket with access only for the owner.
- **FR-006**: The grace policy is the item `__secret-cli.policy` under `.userPresence`. The agent
  reads it after Touch ID. If grace is greater than 3600 or the item has no protection, 0 is used.
- **FR-007**: Store selection: the file `~/.local/state/secret/store` with the word `dp`.
  `migrate` writes it and `migrate --back` deletes it. If the helper does not start, the command
  gives an error. The command does not fall back to the file keychain.
- **FR-008**: `secret migrate --backup FILE` and `secret migrate --back` (User Story 1 and 5).
- **FR-009**: `install.sh` builds the store helper if Xcode and a Personal Team are present.
  `--renew` rebuilds the helper when less than 3 days remain. `--launchd` installs the LaunchAgent.
- **FR-010**: `bin/secret` warns when less than 2 days remain on the profile. The date comes from
  a file that `install.sh` writes, without a run of the helper.
- **FR-011**: Test build: a different bundle ID and access group, Touch ID from a file, an account
  per run, items without `.userPresence`. The release build does not contain this code.
- **FR-012**: The Claude Code hook stops the test build variables and direct calls of the store
  helper by the agent.
- **FR-013**: Without Xcode and before `migrate`, the command works on the file keychain as before.

### Key Entities

- **Item**: name, value, comment, expiry date.
- **Mode file `~/.local/state/secret/store`**: a sign that the new store is on.
- **Policy `__secret-cli.policy`**: grace in seconds.
- **Agent process**: the confirmed Touch ID context, the time when grace ends.

## Success Criteria *(mandatory)*

<!-- ste: E1.9 — SC identifiers set by the spec-kit template -->
- **SC-001**: Test: after `migrate`, all items of the test store have the same values, comments
  and expiry dates. `.env` references work as before.
- **SC-002**: Test: all existing checks of `tests/run.sh` pass on the file keychain. The command
  checks also pass on the test new store.
- **SC-003**: Test: in grace, one command and two commands in a row give one Touch ID question.
  After `lock`, a new question.
- **SC-004**: Manual check: a process with the Personal Team signature reads a working value only
  after Touch ID. `get` asks for Touch ID once.
- **SC-005**: Manual check: the owner's working keychain is moved, the commands work. The helper is
  renewed without a person.
- **SC-006**: The store helper builds without deprecated API warnings.

## Assumptions

- The Personal Team gives a profile for 7 days, and Xcode renews it without questions while the
  Apple ID is added in Xcode (research R3).
- The item attributes (name, comment, expiry date) are not protected by Touch ID, as before
  (research R6).
- The command deletes and replaces an item without Touch ID, as before. These actions do not
  disclose the value.
- The agent process in grace answers any process of the owner, as the grace mark in feature 007 does.
- The file keychain and the helper `secret-auth` stay for the mode without Xcode. Their removal
  goes into a different specification.
