# Implementation Plan: remove the data protection store

**Spec**: `specs/018-drop-data-protection/spec.md`

## Technical Context

The order is important: only the data protection helper can delete the items, so first the delete,
then the code.

1. `helper/store/main.swift`: the `drop` command in the data protection build. Touch ID, then
   `SecItemDelete` for account `secret-cli` and `secret-cli.meta`. `bin/secret`:
   `migrate --drop-dp` — `vault` mode, comparison of the names, call of `drop`. Build, run on the owner's Mac.
2. Code: `main.swift` only for the Secure Enclave store, without `#if VAULT`. Build
   `helper/store/build.sh` (`swiftc`), binary `build/secret-vault`. Delete the Xcode project,
   the entitlements, `build-vault.sh`.
3. `bin/secret`: `vault` mode or the file keychain. `STORE` is always the Secure Enclave helper.
   `migrate --backup FILE` goes to the Secure Enclave, `--back` to the file keychain. The flags `--vault`,
   `--dp`, `--drop-dp` and the variables `SECRET_STORE_HELPER`, `SECRET_STORE_EXPIRES` go away.
   The `dp` mode in the mode file is an error with a hint.
4. `install.sh`: without `--renew` and `--launchd`. It removes the old LaunchAgent and deletes
   `build/SecretStore*`.
5. SecretBar: no profile, no `renew`, no signature notifications. The store is the `vault` mode.
6. Tests: the data protection section goes away. Checks 010, 011, 014 move to section 017.
   The move from the file keychain runs on the Secure Enclave test build.
7. Constitution 2.0.0 (MAJOR): the data protection store is removed.
8. Cleanup on the owner's Mac: LaunchAgent, profile `secretcli.*.store`, `build/SecretStore*`,
   `build/test/SecretStoreTest*`, the agent files `agent.sock`, `agent.lock`, `renew.log`.

## Constitution Check

- I, II: no changes for the Secure Enclave store.
- III: the profile and the Personal Team are no longer necessary.
- V: the commands stay the same, except `migrate --vault` and `--dp` from 017. They lived one day and were necessary
  only for the move.

## Complexity Tracking

The removal of the flags `migrate --vault` and `--dp` is a deviation from V: the data protection store
no longer exists.
