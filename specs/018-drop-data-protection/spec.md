# Feature Specification: remove the data protection store

**Feature Branch**: `018-drop-data-protection`. The work goes on in `main` of the local repository.

**Created**: 2026-10-14

**Status**: Done 2026-10-14

**Input**: The owner moved to the Secure Enclave store (017) and asked to remove the old
data protection store. Everything must stay in working order on his Mac.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - No old copies (Priority: P1)

1. **When** the agent runs `secret migrate --drop-dp`, **Then** the command compares the names: each
   name of the data protection store is in the Secure Enclave store. Then the helper asks for
   Touch ID and deletes all its items: values, service items, policy.
2. The command works only in `vault` mode. In another mode, the command gives an error and
   keeps the items.

### User Story 2 - The project without data protection (Priority: P1)

1. The repository has no Xcode project of the helper, no entitlements and no build with a profile. Xcode is necessary only for
   SecretBar.
2. `install.sh` does not renew the profile. If the LaunchAgent `secretcli.renew` exists, `install.sh`
   removes it.
3. SecretBar does not show the helper signature and the renew button.
4. `secret migrate --backup FILE` moves the file keychain into the Secure Enclave store.
   `secret migrate --back` returns the secrets to the file keychain.
5. The README, the agent rules and the constitution describe two stores: Secure Enclave and the file
   keychain.

### User Story 3 - No fewer tests (Priority: P1)

The checks of grace (idle time, limit, lock, memory), of the clipboard and of `status` run on the test
build of the Secure Enclave helper.

## Requirements *(mandatory)*

- **FR-001**: `secret migrate --drop-dp` deletes the data protection store after the comparison of names and
  Touch ID.
- **FR-002**: the code has no data protection store and no provisioning profile.
- **FR-003**: the owner's Mac has no renewal LaunchAgent, no `SecretStore.app` builds and no profile of the
  bundle `secretcli.*.store`.
- **FR-004**: `tests/run.sh` passes, the tests 009, 010, 011, 014 are moved.

## Success Criteria *(mandatory)*

- **SC-001**: the data protection store is empty.
- **SC-002**: on the owner's Mac, `secret`, SecretBar, ⌥⌘S and Spotlight work with the
  Secure Enclave store.
- **SC-003**: `tests/run.sh` passes in full.

## Assumptions

- The profile of the data protection helper is valid until 2026-10-19. Until this date the helper still starts
  and can delete its items.
