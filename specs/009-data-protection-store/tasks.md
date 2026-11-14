# Tasks: Data protection keychain store

**Input**: `specs/009-data-protection-store/` (spec.md, plan.md, research.md, data-model.md,
contracts/helper-cli.md, quickstart.md)

Tests are part of the tasks: the constitution (IV) requires checks in `tests/run.sh` for each feature.

## Phase 1: Xcode project and build

- [x] T001 Xcode project `helper/SecretStore.xcodeproj/project.pbxproj`: one target, configurations Release and Test (`SWIFT_ACTIVE_COMPILATION_CONDITIONS=SECRET_TEST`, bundle ID `$(SECRET_BUNDLE_ID)-test`), hardened runtime, `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO`. `helper/SecretStore.entitlements` with `$(AppIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)`
- [x] T002 Build function in `install.sh`: Xcode (`DEVELOPER_DIR`), Team ID from `OU` of the Apple Development certificate, `xcodebuild -allowProvisioningUpdates`. The function atomically replaces `build/SecretStore.app`, `build/SecretStore.expires` and `build/SecretStore.src-sha256`. Without Xcode: a message and the file mode

## Phase 2: Helper and store selection

- [x] T003 `helper/secret-store.swift`: `SecItem*` queries (account, access group, attributes from data-model.md), `list`, `has`, batch `write` from stdin, `delete`, `profile`. `Test` build: account and state directory from the environment, items without `.userPresence`, `wipe`
- [x] T004 `helper/secret-store.swift`: agent process — socket, uid check, `LAContext`, policy after Touch ID, grace ≤ 3600. The agent stops by grace, by `lock` and after 30 s idle. The client starts the agent through `posix_spawn` with `SETSID`, a `flock` lock prevents a second agent
- [x] T005 `helper/secret-store.swift`: `read`, `attrs`, `policy show|grace`, `lock` through the agent. Flag `--no-dialog`. An item without `.userPresence` in the release build → code 4 `not protected`
- [x] T006 `bin/secret`: mode file `~/.local/state/secret/store`, `STORE`. Environment variables override `STORE` only together with the test keychain. `dp` branches in `item_exists`, `list_items`, `read_values`, `write_item`, `set_attrs`, a new `delete_item` instead of direct `security delete-generic-password`, `ensure_keychain`

## Phase 3: User Story 1 — secrets in the new store (P1)

**Independent Test**: test build: `migrate` moves the items, the commands give the same result as before.

<!-- ste: E1.9 — US labels set by the spec-kit template -->
- [x] T007 [US1] `bin/secret`: `import` and `restore` as a batch through the helper `write` in mode `dp`
- [x] T008 [US1] `bin/secret`: `secret migrate --backup FILE [--pass-stdin]`. Steps: `export`, read of the old values, write to the new store, policy, comparison, mode file, deletion of the old copies from the file keychain. On an error, the command does not change the mode
<!-- ste: E1.9 — SC labels set by the spec-kit template -->
- [x] T009 [US1] `tests/run.sh`: `Test` build in `build/test/`, cache by the source hash. Without Xcode: skip with a message. `migrate` and all commands in mode `dp` (SC-001, SC-002). Deletion of the run items

## Phase 4: User Story 2 — value only after Touch ID (P1)

- [x] T010 [US2] `tests/run.sh`: one question for `get`, `run` with several names, `export`. `SECRET_NO_DIALOG=1` and a refusal: an error without output. `ls`, `has`, `check`, `set`, `rm` without a question
- [x] T011 [US2] Manual check of SC-004, 2026-10-07. After `secret lock`, a probe with the signature of the same Personal Team and with the access group of the working store reads the item attributes (`0`). A read of the value gives `-25308`, the probe does not get the value. The owner saw the Touch ID windows during `migrate` and `run`

## Phase 5: User Story 4 — profile renewal (P1)

- [x] T012 [US4] `install.sh --renew`: rebuild if less than 3 days remain until expiry or the source has changed. Deletion of the old profile of this bundle ID. On an error: a message about sign-in to Xcode
- [x] T013 [US4] `install.sh --launchd`: `~/Library/LaunchAgents/secretcli.renew.plist`, once a day and at login, log `~/.local/state/secret/renew.log`
- [x] T014 [US4] `bin/secret`: a warning in stderr if less than 2 days remain on the profile or it has expired. An error with a hint if the helper does not start
- [x] T015 [US4] `tests/run.sh`: expiry warning from a substituted expiry file
- [x] T016 [US4] Manual check: renewal through the LaunchAgent gives a new expiry date. Check on 2026-10-07: the date in `build/SecretStore.expires` was set to one day ahead. `launchctl kickstart gui/$UID/secretcli.renew` deleted the profile, Xcode gave a new one until 2026-10-14 13:57 (it was 13:52). We did not wait for a real expiry

## Phase 6: User Story 3 — grace (P2)

- [x] T017 [US3] `bin/secret`: `touchid status|grace|on|off`, `lock`, `unlock`, `init` in mode `dp`
- [x] T018 [US3] `tests/run.sh`: two commands in grace — one question. `lock` — a new question. Grace 0 — a question each time. Grace > 3600 — an error. `touchid off` — an error (SC-003)

## Phase 7: User Story 5 — move back (P3)

- [x] T019 [US5] `bin/secret`: `secret migrate --back`: read from the new store, write to the file keychain, comparison, deletion of the mode file and of the new store items
- [x] T020 [US5] `tests/run.sh`: `migrate --back` keeps values, comments, expiry dates

## Phase 8: Hook, documents, measurements

- [x] T021 [P] `hooks/claude-pretooluse.sh`: the variables `SECRET_STORE_*`, `SECRET_TEST_*` and a direct call of `SecretStore` by the agent. Hook tests
- [x] T022 [P] `README.md`, `docs/claude-md-secrets.md`, the Secrets section in `~/.claude/CLAUDE.md`, `usage` in `bin/secret`, `completions/_secret` (`migrate`)
- [x] T023 Release build without deprecated API warnings (SC-006): `xcodebuild` Release — 0 lines with `deprecat`, 2026-10-07
- [x] T024 Full `tests/run.sh`: 262 checks, 2026-10-07. Measurement on 300 items (`N=300` and `DP=1 N=300 tests/bench.sh`):

  | Command | file keychain | data protection |
  |---|---|---|
  | `import` 300 values | 4.67 s | 4.04 s |
  | `ls -l` | 0.07 s | 0.09 s |
  | `run` 5 references | 0.19 s | 0.17 s |
  | `check` 300 keys | 0.59 s | 0.65 s |
  | `set` | 0.14 s | 0.15 s |
  | `get` | 0.09 s | 0.09 s |
- [x] T025 Manual check of SC-005, 2026-10-07. `secret migrate --backup ~/secrets-before-dp-2026-10-07.bak`: 49 secrets in the new store, 0 items in `secrets.keychain-db`. `ls`: 49 names without Touch ID. `run` with one reference works. `touchid status`: `store: data protection keychain`. The LaunchAgent `secretcli.renew` is installed (T013, T016). The first attempt with a backup password shorter than 12 characters changed nothing and found an error in `export`. The error is fixed, a test exists

## Dependencies

<!-- ste: E4.2, E1.9 — task dependency chain, US labels set by the spec-kit template -->
T001 → T002 → T003 → T004 → T005 → T006 → US1 (T007–T009) → US2, US4, US3, US5 → Polish.
US2, US4, US3, US5 depend only on Phase 2 and US1.

## Parallel

T021 and T022 are different files. T012–T013 (`install.sh`) go in parallel with T017 (`bin/secret`).

<!-- ste: E1.1 — heading set by the spec-kit template -->
## Implementation Strategy

The minimum working version (MVP) is Phase 1–4 and US4. Without renewal, the helper stops starting
after one week. Then grace,
the move back, the documents. The move of the working keychain (T025) comes last, after all tests.
