# Feature Specification: Secure Enclave store without a signature expiry

**Feature Branch**: `017-secure-enclave-store`. The work goes on in `main` of the local repository.

**Created**: 2026-10-14

**Status**: Done 2026-10-14

**Input**: The owner likes how the data protection store works. But its helper lives on
a profile of the free Personal Team, and the profile expires after 7 days. The renewal runs by itself once a
day, but needs a sign-in to Xcode and the network. The owner wants the same experience without the renewal.

Prototype 2026-10-14 (agent; the owner did the touches):

- A program with an ad-hoc signature created a P-256 key in the Secure Enclave. It did not need a team or
  entitlements.
- The key works only after confirmation. Otherwise the system answers "User interaction is
  required".
- With `.userPresence`, the confirmation also comes to the Apple Watch.
- The key wrapper also works in another program. So an item of the file keychain keeps the wrapper.
  Only the helper reads this item without a prompt.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The same experience without an expiry (Priority: P1)

1. **Given** the Secure Enclave store is on, **When** the agent or the owner reads a secret,
   **Then** macOS asks for Touch ID or Apple Watch once. Then grace applies.
   Grace is 30 minutes of idle time, 8 hours at most. A screen lock, sleep and `secret lock` end grace.
2. `ls`, `has`, `check`, `note`, `expire`, `set`, `gen`, `ask`, `import` work without Touch ID.
3. SecretBar, the quick panel, Spotlight and the log work as before.
4. The command and SecretBar say nothing about the profile and the renewal.

### User Story 2 - Move with one command (Priority: P1)

1. **When** the owner runs `secret migrate --vault`, **Then** the command reads all values
   from the data protection store (one touch). It writes them to the new store. Then it reads
   them from the new store (one touch) and compares them. Only after that the command switches
   the mode to the new store.
2. The command keeps the items of the data protection store. `secret migrate --dp` takes the command
   back there and moves the changes back.
3. `secret migrate --back` from the new store moves the secrets to the file keychain.

### User Story 3 - Another program cannot read the secrets (Priority: P1)

1. Without the file key, the store file is noise: names and comments in it are not visible.
2. Only the helper reads the file key and the Secure Enclave key wrapper without a prompt. Another program
   gets the system keychain password prompt.
3. The helper rejects a replaced or damaged file and does not write over it.

### Edge Cases

- The store file exists, the keychain item does not. The helper exits with an error and keeps the previous
  key. `secret touchid repair` restores the item.
- Two writes at the same time: the second waits for the first (file lock).
- A failure during a write: the previous file stays intact (write to a temporary file and rename).
- The Secure Enclave key is lost (the Mac is erased): the values cannot be read. Recovery is from a
  `secret export` backup.

## Requirements *(mandatory)*

- **FR-001**: the new helper understands the same requests as the data protection helper: `list`, `has`,
  `read`, `write`, `attrs`, `delete`, `policy`, `lock`, `status`, `grace-status`, `clip`,
  `ping`, `kind`.
- **FR-002**: a value in the file is encrypted with the Secure Enclave public key, the whole file with the file
  key. A value does not go to the disk as plain text.
- **FR-003**: the confirmation is `.userPresence`: Touch ID, Apple Watch or the Mac password.
- **FR-004**: grace, the 8-hour limit, lock, sleep and `lock` work as in data protection.
- **FR-005**: `secret migrate --vault`, `--dp`, `--back` with a check of each value.
- **FR-006**: `install.sh` builds the helper through `swiftc`, without Xcode and a profile.
- **FR-007**: `touchid status` in the new store writes `store: secure enclave` and does not write
  the profile. SecretBar does not show the profile warning.
- **FR-008**: the tests pass on the test build with a software key.

## Success Criteria *(mandatory)*

- **SC-001**: after the move, all 65 secrets can be read, the values match.
- **SC-002**: one `secret run` command with several names asks for confirmation once,
  the second one in grace not at all.
- **SC-003**: the helper works after October 19, 2026, when the last profile expires, without
  `install.sh --renew`.
- **SC-004**: `tests/run.sh` passes in full.

## Assumptions

- The Secure Enclave key is bound to this Mac, as the `ThisDeviceOnly` items are now.
- Names and comments inside the helper and in the `ls` output are not a secret for the owner and the agent, as
  now.
