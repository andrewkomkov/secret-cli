# Tasks: SecretBar menu bar app

**Input**: `specs/012-menu-bar-app/` (spec.md, plan.md)

- [x] T001 `app/SecretBar.xcodeproj`, `app/build.sh`: ad-hoc build, hardened runtime, `LSUIElement`
- [x] T002 [US1] `app/SecretBar/Model.swift`: calls of `secret` and the helper, parsing of `list`, `grace-status`, `policy show`, the access log
- [x] T003 [US1] `app/SecretBar/SecretBarApp.swift`: icon by state, poll once in 5 seconds
- [x] T004 [US2] `app/SecretBar/Views.swift`: list, search, copy, add, generate, edit, rename, delete
- [x] T005 [US3] `app/SecretBar/Views.swift`: the "Activity" tab
- [x] T006 [US4] `app/SecretBar/Views.swift`: the "Settings" tab
- [x] T007 `app/SecretBar/Model.swift`: `--selftest`
- [x] T008 `install.sh --app`, `tests/run.sh`: build, `--selftest`, binary check. 290 checks, 2026-10-07
- [x] T009 `README.md`: a section about the app
- [ ] T010 Manual check of SC-002. Record the date
