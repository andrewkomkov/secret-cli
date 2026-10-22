# Tasks: SecretBar сам восстанавливает индекс Spotlight

**Input**: `specs/016-spotlight-self-heal/spec.md`

- [x] T001 [US1] `app/SecretBar/SecretBarApp.swift`: `SpotlightIndex.count()`, `--spotlight-check`
  через неё, `--spotlight-clear` для проверки
- [x] T002 [US1] `app/SecretBar/Model.swift`: `Store.healSpotlight()` при запуске и каждые 10 минут
- [x] T003 `app/SecretBar/Model.swift`: `Store.shared` в демо-режиме при запуске с флагами проверки
- [x] T004 Сборка, установка, живая проверка SC-001 агентом 2026-10-08: SecretBar запущен в
  18:02:47, индекс очищен в 18:03:03 (0 записей), в 18:13:07 снова 65 записей без перезапуска.
  `tests/run.sh`: 301 проверка проходит
