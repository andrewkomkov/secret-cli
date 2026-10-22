# Tasks: Скользящий grace

**Input**: `specs/010-sliding-grace/` (spec.md, plan.md)

## Phase 1: Агент helper

- [x] T001 `helper/store/main.swift`: цикл агента на `RunLoop` главного потока, сокет через `DispatchSource`
- [x] T002 [US1] `helper/store/main.swift`: после каждого запроса конец grace — сейчас плюс простой, не позже предела 8 часов от Touch ID по `CLOCK_MONOTONIC` (эти часы идут и во сне)
- [x] T003 [US2] `helper/store/main.swift`: агента завершают уведомление `com.apple.screenIsLocked` и опрос `CGSessionCopyCurrentDictionary` раз в секунду и перед запросом. Сон Mac агент видит по разнице часов `CLOCK_MONOTONIC` и `CLOCK_UPTIME_RAW` больше 2 секунд
- [x] T004 [US3] `helper/store/main.swift`: запрос `status` к агенту без Touch ID; команда `grace-status`; простой по умолчанию 1800
- [x] T005 `helper/store/main.swift`: сборка `Test` — предел из `SECRET_TEST_MAX_GRACE`, команда `test-lock` шлёт уведомление `secretcli.test.lock`

## Phase 2: Команда

- [x] T006 [US3] `bin/secret`: `touchid status` показывает простой, предел и остаток grace; `migrate` по умолчанию ставит 1800

## Phase 3: Тесты и документы

- [x] T007 `tests/run.sh`: SC-001 (простой), SC-002 (предел), SC-003 (`test-lock`), `touchid status`. 268 проверок, 2026-10-07. Сон Mac в тестах не проверяется
- [x] T008 [P] `README.md`, `docs/claude-md-secrets.md`, раздел Secrets в `~/.claude/CLAUDE.md`: скользящий grace
- [x] T010 `helper/store/main.swift`: агент после Touch ID читает все записи в память. Запрос отдаёт значение из памяти при той же ссылке записи. Иначе агент читает запись, а при контексте старше 8 минут сначала спрашивает Touch ID со своим текстом (research R11)
- [x] T011 `helper/store/main.swift`: `attrs` переписывает запись значением из памяти, без Touch ID
- [x] T012 `tests/run.sh`: значение из памяти без нового вопроса после срока контекста (`SECRET_TEST_CONTEXT_FRESH`). Изменённая запись — новый вопрос. `note` без вопроса. 274 проверки, 2026-10-07
- [ ] T013 Ручная проверка R11: `secret run` через 15 минут после Touch ID без окна. Записать дату
- [ ] T009 Ручная проверка SC-004: блокировка экрана владельцем заканчивает grace. Записать дату

## Dependencies

T001 → T002 → T003 → T004 → T005 → T006 → T007 → T008, T009.
