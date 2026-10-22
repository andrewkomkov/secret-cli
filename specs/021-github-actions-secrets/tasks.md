# Tasks: секрет в GitHub Actions

**Input**: `specs/021-github-actions-secrets/spec.md`

- [x] T001 Конституция 2.1.0
- [x] T002 [US1] `bin/secret`: `cmd_gh`, `confirm`, справка
- [x] T003 [US2] `hooks/claude-pretooluse.sh`: `SECRET_GH`, `SECRET_CONFIRM` только для тестов
- [x] T004 [US1] `completions/_secret`, SecretBar: имя операции в журнале
- [x] T005 `tests/run.sh`: 15 проверок 021 на поддельном `gh`
- [x] T006 `README.md`, `docs/claude-md-secrets.md`
- [ ] T007 Ручная проверка: окно подтверждения, `secret gh` в тестовую репу, `gh secret list` показывает имя
