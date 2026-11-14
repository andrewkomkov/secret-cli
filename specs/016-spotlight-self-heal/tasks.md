# Tasks: SecretBar restores the Spotlight index itself

**Input**: `specs/016-spotlight-self-heal/spec.md`

- [x] T001 [US1] `app/SecretBar/SecretBarApp.swift`: `SpotlightIndex.count()`, `--spotlight-check`
  through it, `--spotlight-clear` for the check
- [x] T002 [US1] `app/SecretBar/Model.swift`: `Store.healSpotlight()` at launch and every 10 minutes
- [x] T003 `app/SecretBar/Model.swift`: `Store.shared` in demo mode at a launch with check flags
- [x] T004 Build, install, live check of SC-001 by the agent 2026-10-08: SecretBar started at
  18:02:47, the index cleared at 18:03:03 (0 entries), at 18:13:07 again 65 entries without a restart.
  `tests/run.sh`: 301 checks pass
