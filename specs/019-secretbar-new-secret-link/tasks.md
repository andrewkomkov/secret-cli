# Tasks: SecretBar — "New secret…" in the menu and a reference after create

**Input**: `specs/019-secretbar-new-secret-link/spec.md`

- [x] T001 [US1] `QuickPanel.swift`: `Navigation.newSecret()`; `MainWindow.swift`: sheet on request
- [x] T002 [US1] `Views.swift`: the item "New secret…" in the "…" menu
- [x] T003 [US2] `MainWindow.swift`, `Model.swift`: reference into the clipboard after create
- [x] T004 Build `app/build.sh`, `tests/run.sh`: 309 of 309
- [ ] T005 Manual check: the menu item opens the sheet, after "Save" the clipboard holds `secret:NAME`
