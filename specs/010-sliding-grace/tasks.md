# Tasks: Sliding grace

**Input**: `specs/010-sliding-grace/` (spec.md, plan.md)

## Phase 1: Helper agent

- [x] T001 `helper/store/main.swift`: agent loop on the `RunLoop` of the main thread, socket through `DispatchSource`
- [x] T002 [US1] `helper/store/main.swift`: after each request, the end of grace is now plus the idle time, not later than the limit of 8 hours from Touch ID by `CLOCK_MONOTONIC` (this clock also runs during sleep)
- [x] T003 [US2] `helper/store/main.swift`: the agent is stopped by the notification `com.apple.screenIsLocked` and by a poll of `CGSessionCopyCurrentDictionary` once a second and before a request. The agent sees Mac sleep from a difference of more than 2 seconds between the clocks `CLOCK_MONOTONIC` and `CLOCK_UPTIME_RAW`
- [x] T004 [US3] `helper/store/main.swift`: the request `status` to the agent without Touch ID; the command `grace-status`; default idle time 1800
- [x] T005 `helper/store/main.swift`: the `Test` build: the limit from `SECRET_TEST_MAX_GRACE`, the command `test-lock` sends the notification `secretcli.test.lock`

## Phase 2: Command

- [x] T006 [US3] `bin/secret`: `touchid status` shows the idle time, the limit and the grace remaining; `migrate` sets 1800 by default

## Phase 3: Tests and documents

- [x] T007 `tests/run.sh`: SC-001 (idle time), SC-002 (limit), SC-003 (`test-lock`), `touchid status`. 268 checks, 2026-10-07. The tests do not check Mac sleep
- [x] T008 [P] `README.md`, `docs/claude-md-secrets.md`, the Secrets section in `~/.claude/CLAUDE.md`: sliding grace
- [x] T010 `helper/store/main.swift`: after Touch ID, the agent reads all items into memory. A request gets the value from memory if the item reference is the same. If not, the agent reads the item; if the context is older than 8 minutes, it first asks for Touch ID with its own text (research R11)
- [x] T011 `helper/store/main.swift`: `attrs` rewrites the item with the value from memory, without Touch ID
- [x] T012 `tests/run.sh`: a value from memory without a new question after the context lifetime (`SECRET_TEST_CONTEXT_FRESH`). A changed item gives a new question. `note` without a question. 274 checks, 2026-10-07
- [ ] T013 Manual check of R11: `secret run` 15 minutes after Touch ID without a window. Record the date
- [ ] T009 Manual check of SC-004: a screen lock by the owner ends grace. Record the date

## Dependencies

T001 → T002 → T003 → T004 → T005 → T006 → T007 → T008, T009.
