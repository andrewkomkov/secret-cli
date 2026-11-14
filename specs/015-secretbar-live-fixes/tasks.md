# Tasks: SecretBar — fixes after the live check

**Input**: `specs/015-secretbar-live-fixes/spec.md`

- [x] T001 [US1] `app/SecretBar/Model.swift`: `Parse.swapLayout`, `Store.filter` with the other layout
- [x] T002 [US2] `app/SecretBar/MainWindow.swift`: empty section, card only from the list
- [x] T003 [US2] `app/SecretBar/Model.swift`, `MainWindow.swift`: `.env` key from the reference index
- [x] T004 [US3] `MainWindow.swift`, `Views.swift`, `QuickPanel.swift`: VoiceOver labels
- [x] T005 [US4] `app/SecretBar/SecretBarApp.swift`: `--spotlight-check`
- [x] T006 [US4] `Model.swift` `SelfTest`: layout, references with a key, search time on 2000
- [x] T007 [US4] `app/SecretBar/Snapshot.swift`: empty section, 300 secrets; review of the snapshots
- [x] T008 `tests/run.sh`: `--spotlight-check` on the installed app
- [x] T009 Build, install into `/Applications`, live check by the agent 2026-10-08: `jenkins` typed on Russian keys in the
  quick panel finds `JENKINS_ADMIN_PASSWORD`; VoiceOver reads the search field of the panel as
  "Search for a secret. Return copies the selected one"; `--spotlight-check` — 65 entries. Empty section and
  list of 300 secrets — from the `--snapshot` images (`main-empty`, `main-many`)
