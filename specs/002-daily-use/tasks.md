# Tasks: Удобство каждый день

**Input**: `specs/002-daily-use/` (spec.md, plan.md)

## Phase 1: Основа

- [x] T001 `write_item` с атрибутом `gena`, чтение `gena` и `icmt` одной функцией
- [x] T002 Кэш имён `refresh_names` после `ls`, `set`, `gen`, `rm`; переменная `SECRET_NAMES_CACHE`

## Phase 2: User Story 1 — copy (P1)

- [x] T003 [US1] `secret copy NAME [SECONDS]`, очистка буфера, запись в журнал
- [x] T004 [US1] Тесты на подменённом буфере: значение в буфере, очистка, чужой текст остаётся, значения нет в выводе

## Phase 3: User Story 3 — mv (P2)

- [x] T005 [US3] `secret mv [-f] OLD NEW`
- [x] T006 [US3] Тесты: значение, комментарий и срок перенесены, OLD нет, отказ без `-f`

## Phase 4: User Story 4 — срок жизни (P2)

- [x] T007 [US4] `set -x DATE`, `secret expire NAME DATE|none`, проверка даты
- [x] T008 [US4] `ls --expiring [DAYS]`, дата в `ls -l`, предупреждение в `run` и `check`
- [x] T009 [US4] Тесты: сохранение, удаление, неверная дата, `--expiring`, предупреждение

## Phase 5: User Story 2 — автодополнение (P2)

- [x] T010 [US2] `completions/_secret`
- [x] T011 [US2] `install.sh` ставит `_secret` в `$ZSH_CUSTOM/completions`
- [ ] T012 [US2] Проверка: `zsh -n`, и Tab в терминале владельца (ручная проверка) **`zsh -n` и загрузка `_secret` в zsh проверены 2026-10-02, Tab ждёт владельца**

## Phase 6: Документы

- [x] T013 README, `secret help`, `docs/claude-md-secrets.md`, раздел Secrets в `~/.claude/CLAUDE.md`
