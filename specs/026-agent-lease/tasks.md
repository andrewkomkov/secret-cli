# Tasks: Secret lease for agents

**Input**: `specs/026-agent-lease/` (spec.md, plan.md, research.md, contracts/cli.md, data-model.md)

## Phase 1: Constitution

<!-- utr-100: 4.2 — spec-kit task line: file, action and conditions in one item -->
- [x] T001 `.specify/memory/constitution.md`: principle II — lease rule (explicit set of names, a new Touch ID for each lease, a term of up to 24 hours, a lock and a sleep end only grace, `lock` also ends the lease). Version 2.4.0, a separate commit `docs(constitution): ...` before the code

## Phase 2: Helper agent (base for all stories)

<!-- utr-100: 4.2, 8.1 — spec-kit task lines: file, action and conditions in one item -->
- [x] T002 `helper/store/main.swift`: lease table in `Agent`: `name → (ref, value, end)`, limit `maxLease` 24 hours, in the `Test` build from `SECRET_TEST_MAX_LEASE`
- [x] T003 `helper/store/main.swift`: `endGrace()` instead of `stop()` on a screen lock and a sleep: close the context, clear the grace cache. If there is no lease, the agent exits, as before. `lock` still stops the agent. Check `check()`: the end of each leased name by `CLOCK_MONOTONIC`
- [x] T004 `helper/store/main.swift`: `Test` build — agent lock flag for `screenLocked()`. `test-lock` sets the flag and ends grace, `test-unlock` clears the flag, `test-sleep` ends grace (research R7)

## Phase 3: User Story 1 — the agent works while the screen is locked (P1)

**Independent Test**: lease A, then `test-lock`. `secret run A` works without Touch ID.
`secret run B` at once gives `not leased: B`.

- [x] T005 [US1] `helper/store/main.swift`: the `read` request first looks at the lease table (the same reference `r` and the term has not passed). The answer gets a sources field `l`/`g` (research R6)
- [x] T006 [US1] `helper/store/main.swift`: while the screen is locked, names outside the lease give `err 6 not leased: A, B` without `confirmedContext` (FR-007)
- [x] T007 [US1] `helper/store/main.swift`: the `read` command writes the sources to stderr as a line `source: ...`. `bin/secret` in `run`/`get` writes the detail `lease` to the log for leased names and does not show this line (FR-009)

## Phase 4: User Story 2 — lease request (P1)

**Independent Test**: `secret lease --for 1h A` with the answer "yes" gives a lease, with "no" an error and no lease.

<!-- utr-100: 4.2 — spec-kit task line: file, action and conditions in one item -->
- [x] T008 [US2] `helper/store/main.swift`: agent request `lease` — always a new `confirmedContext` with the text from the contract, a read of the named values, addition to the table (the later end for a repeated name). Command `lease SECONDS NAME...`. Errors on a screen lock and `SECRET_NO_DIALOG` (contracts/cli.md)
<!-- utr-100: 4.2 — spec-kit task line: file, action and conditions in one item -->
- [x] T009 [US2] `bin/secret`: `cmd_lease` per contracts/cli.md: `--for`, names or `-e FILE`. Check of the names before the window, error for the file keychain, log `lease`. Lines in `help` and `usage`
- [x] T010 [P] [US2] `hooks/claude-pretooluse.sh`: check that the hook lets `secret lease`, `secret lease status`, `secret lease --revoke` through. Change it only if the hook stops them

## Phase 5: User Story 3 — end of the lease (P1)

**Independent Test**: `SECRET_TEST_MAX_LEASE=2`, after 3 seconds `not leased`. `--revoke`, `lock` and `set` end the lease.

- [x] T011 [US3] `helper/store/main.swift`: request `revoke` and command `lease-revoke`. `bin/secret lease --revoke`, log `lease-revoke`
- [x] T012 [US3] `helper/store/main.swift`: a name leaves the lease if the record reference is different or the record is gone (research R4). Check on read and in `lease-status`

## Phase 6: User Story 4 — status, log, SecretBar (P2)

<!-- utr-100: 8.1 — spec-kit task lines: file, action and conditions in one item -->
- [x] T013 [US4] `helper/store/main.swift`: request `lease-status`, command `lease-status`; field `lease=N:END` in the `status` line for SecretBar. `bin/secret lease status` per the contract
- [x] T014 [US4] `app/SecretBar/`: line of the active lease (number of names, end) and the button "Revoke lease", call of `bin/secret lease --revoke`. `ru` translation in `Localizable.xcstrings`

## Phase 7: Tests and documents

<!-- utr-100: 4.2 — spec-kit task lines: file, action and conditions in one item -->
- [x] T015 `tests/run.sh`: SC-001 (lease after `test-lock`, `not leased` for another name in less than 1 second, `test-sleep`), SC-002 (`SECRET_TEST_MAX_LEASE`), SC-003 (`--revoke`, `lock`, `set`, `rm`), SC-004 (`--for 25h`, Touch ID refusal, empty `-e`), `lease status`, mark `lease` in the log, grace after `test-lock` ends as before
- [x] T016 [P] `docs/claude-md-secrets.md`: rule for the agent (FR-012)
- [x] T017 [P] `README.md`, `README.ru.md`, `site/`: command `secret lease`
- [ ] T018 Manual check SC-005: lease by the agent, Touch ID, screen lock for 30 minutes, the leased secret and an error for another. Record the date
- [ ] T019 Manual check SC-006: lease after a Mac sleep. Record the date
- [ ] T020 Manual check of SecretBar: lease line and revoke. Record the date

## Dependencies

<!-- utr-100: 4.2 — task dependency chain -->
T001 → T002 → T003 → T004 → (T005..T007) → (T008, T009) → (T011, T012) → T013 → T014 → T015.
T010, T016, T017 — after T009, in parallel. T018..T020 — after T015 and a rebuild of the helper and SecretBar.

## Implementation Strategy

MVP is phases 1–5: lease from the CLI, work during a lock, end of the lease. SecretBar (T014)
comes in the next commit.
