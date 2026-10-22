# Tasks: SecretBar — исправления после живой проверки

**Input**: `specs/015-secretbar-live-fixes/spec.md`

- [x] T001 [US1] `app/SecretBar/Model.swift`: `Parse.swapLayout`, `Store.filter` с другой раскладкой
- [x] T002 [US2] `app/SecretBar/MainWindow.swift`: пустой раздел, карточка только из списка
- [x] T003 [US2] `app/SecretBar/Model.swift`, `MainWindow.swift`: ключ `.env` из индекса ссылок
- [x] T004 [US3] `MainWindow.swift`, `Views.swift`, `QuickPanel.swift`: подписи VoiceOver
- [x] T005 [US4] `app/SecretBar/SecretBarApp.swift`: `--spotlight-check`
- [x] T006 [US4] `Model.swift` `SelfTest`: раскладка, ссылки с ключом, время поиска по 2000
- [x] T007 [US4] `app/SecretBar/Snapshot.swift`: пустой раздел, 300 секретов; просмотр снимков
- [x] T008 `tests/run.sh`: `--spotlight-check` на установленном приложении
- [x] T009 Сборка, установка в `/Applications`, живая проверка агентом 2026-10-08: `оутлшты` в
  быстрой панели находит `JENKINS_ADMIN_PASSWORD`; поле поиска панели читается VoiceOver как
  «Поиск секрета. Ввод копирует выбранный»; `--spotlight-check` — 65 записей. Пустой раздел и
  список на 300 секретов — по снимкам `--snapshot` (`main-empty`, `main-many`)
