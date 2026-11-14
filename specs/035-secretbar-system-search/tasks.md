# Tasks: SecretBar в системном поиске Siri и Spotlight

**Input**: `specs/035-secretbar-system-search/spec.md`, `plan.md`

- [x] T001 [US1] `SearchSecretsIntent` со схемой `.system.search`
- [x] T002 [US1] `Navigation.search`, `MainWindow.takeSearchRequest`
- [x] T003 [US2] `SecretQuery: IndexedEntityQuery` на macOS 27
- [x] T004 2026-11-11: новых строк интерфейса нет. Название действия даёт схема `.system.search`, `Localizable.xcstrings` не менялся
- [x] T005 2026-11-11 `app/build.sh` на Xcode 27.2 собирает SecretBar, в `Metadata.appintents` есть `SearchSecretsIntent` и `system.search`; `tests/run.sh` 560 из 560
- [x] T006 README, README.ru: поиск SecretBar из Siri и Spotlight
- [x] T007 2026-11-11 CI PR #13 зелёный на `macos-15` и `macos-26` (после фикса макроса для Xcode 16)
- [ ] T008 ручная SC-002. Дата — при выполнении
