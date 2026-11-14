# Tasks: SecretBar in the Siri and Spotlight system search

**Input**: `specs/035-secretbar-system-search/spec.md`, `plan.md`

- [x] T001 [US1] `SearchSecretsIntent` with the schema `.system.search`
- [x] T002 [US1] `Navigation.search`, `MainWindow.takeSearchRequest`
- [x] T003 [US2] `SecretQuery: IndexedEntityQuery` on macOS 27
- [x] T004 2026-11-11: no new interface strings. The schema `.system.search` gives the action name; `Localizable.xcstrings` did not change
- [x] T005 2026-11-11 `app/build.sh` on Xcode 27.2 builds SecretBar, `Metadata.appintents` has `SearchSecretsIntent` and `system.search`; `tests/run.sh` 560 of 560
- [x] T006 README, README.ru: SecretBar search from Siri and Spotlight
- [x] T007 2026-11-11 CI of PR #13 is green on `macos-15` and `macos-26` (after the macro fix for Xcode 16)
- [ ] T008 manual SC-002. Date — when done
