# Tasks: Приложение в строке меню SecretBar

**Input**: `specs/012-menu-bar-app/` (spec.md, plan.md)

- [x] T001 `app/SecretBar.xcodeproj`, `app/build.sh`: сборка ad-hoc, hardened runtime, `LSUIElement`
- [x] T002 [US1] `app/SecretBar/Model.swift`: вызовы `secret` и helper, разбор `list`, `grace-status`, `policy show`, журнала доступа
- [x] T003 [US1] `app/SecretBar/SecretBarApp.swift`: значок по состоянию, опрос раз в 5 секунд
- [x] T004 [US2] `app/SecretBar/Views.swift`: список, поиск, копирование, добавление, генерация, изменение, переименование, удаление
- [x] T005 [US3] `app/SecretBar/Views.swift`: вкладка «Активность»
- [x] T006 [US4] `app/SecretBar/Views.swift`: вкладка «Настройки»
- [x] T007 `app/SecretBar/Model.swift`: `--selftest`
- [x] T008 `install.sh --app`, `tests/run.sh`: сборка, `--selftest`, проверка бинарника. 290 проверок, 2026-10-07
- [x] T009 `README.md`: раздел о приложении
- [ ] T010 Ручная проверка SC-002. Записать дату
