# Tasks: Служебные записи без Touch ID

**Input**: `specs/011-meta-items/` (spec.md, plan.md, research.md)

- [x] T001 `helper/store/main.swift`: служебные записи `secret-cli.meta`. С ними работают `list`, `has`, `attrs`, `policy show` и проверка изменения в агенте
- [x] T002 `helper/store/main.swift`: `ping`, `reindex`, журнал агента, журнал обращений тестовой сборки `SECRET_TEST_VALUE_LOG`
- [x] T003 `bin/secret`: проверка через `ping`, команда `__reindex`
- [x] T004 `tests/run.sh`: только агент обращается к записям со значением. `note` и `expire` работают без Touch ID. 278 проверок, 2026-10-07
- [x] T005 Возврат скользящего grace из 010 на основе служебных записей
- [x] T006 Конституция 1.3.0, исправления в research 009 R6 и 010 R11
- [x] T007 `README.md`, `docs/claude-md-secrets.md`, раздел Secrets в `~/.claude/CLAUDE.md`
- [x] T008 Ручная проверка SC-002, 2026-10-07. `__reindex` создал 50 служебных записей, 1 окно. `ls`, `ls -l`, `has`, `touchid status` — 0 окон. Два `run` — 1 окно (R14)
