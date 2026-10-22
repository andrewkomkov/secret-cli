# Tasks: Защита от утечек при работе агента

**Input**: `specs/001-agent-safety/` (spec.md, plan.md)

## Phase 1: User Story 1 — gen (P1)

- [x] T001 [US1] `secret gen` с `-l`, `-s alnum|symbols|hex`, `-c`, `-f`
- [x] T002 [US1] Тесты: длина, набор символов для трёх наборов, отказ без `-f`, замена с `-f`, значения нет в выводе

## Phase 2: User Story 2 — run --mask (P1)

- [x] T003 [US2] `secret run --mask` и `SECRET_RUN_MASK=1`: stdout и stderr через маскировщик, код выхода команды
- [x] T004 [US2] Тесты: `***` в stdout и stderr, код выхода 7, значение внутри другого значения, простые значения `.env` не маскируются

## Phase 3: User Story 3 — журнал (P2)

- [x] T005 [US3] Функция `audit` в `get` и `run`, `SECRET_LOG`, права 600
- [x] T006 [US3] `secret log [-n N] [NAME]`
- [x] T007 [US3] Тесты: строки после `get` и `run`, поле `agent`/`human`, значений в файле нет, `SECRET_LOG=off`

## Phase 4: User Story 4 — хук Claude Code (P2)

- [x] T008 [US4] `hooks/claude-pretooluse.sh`: 8 шаблонов из spec.md, код 2 и причина
- [x] T009 [US4] Тесты хука: 8 блокировок и 5 пропусков (SC-002) **2026-10-02**: 12 блокировок и 8 пропусков. Сначала хук блокировал слова в тексте (heredoc, сообщения коммитов). Теперь правила смотрят на начало команды, и на это есть тесты
- [x] T010 [US4] `install.sh --claude-hook`: добавить хук в `~/.claude/settings.json`, не трогая остальные настройки
- [x] T011 [US4] Установить хук у владельца и проверить из Claude Code: `secret get` блокируется (ручная проверка) **2026-10-02**: хук стоит в `~/.claude/settings.json`, команда из Claude Code остановлена с причиной

## Phase 5: Документы

- [x] T012 README, `secret help`, `docs/claude-md-secrets.md` и раздел Secrets в `~/.claude/CLAUDE.md`
