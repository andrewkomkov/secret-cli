# Tasks: Аренда секретов для агентов

**Input**: `specs/026-agent-lease/` (spec.md, plan.md, research.md, contracts/cli.md, data-model.md)

## Phase 1: Конституция

<!-- утр-100: 4.2 — строка задачи spec-kit: файл, действие и условия в одном пункте -->
- [x] T001 `.specify/memory/constitution.md`: принцип II — правило аренды (явный набор имён, новый Touch ID на каждую аренду, срок до 24 часов, блокировка и сон заканчивают только grace, `lock` заканчивает и аренду). Версия 2.4.0, отдельный коммит `docs(constitution): ...` до кода

## Phase 2: Агент helper (основа для всех историй)

<!-- утр-100: 4.2, 8.1 — строки задач spec-kit: файл, действие и условия в одном пункте -->
- [x] T002 `helper/store/main.swift`: таблица аренды в `Agent`: `name → (ref, value, end)`, предел `maxLease` 24 часа, в сборке `Test` — из `SECRET_TEST_MAX_LEASE`
- [x] T003 `helper/store/main.swift`: `endGrace()` вместо `stop()` при блокировке экрана и сне: закрыть контекст, очистить кэш grace. Если аренды нет, агент завершается, как раньше. `lock` по-прежнему завершает агент. Проверка `check()`: конец каждого имени аренды по `CLOCK_MONOTONIC`
- [x] T004 `helper/store/main.swift`: сборка `Test` — флаг блокировки агента для `screenLocked()`. `test-lock` ставит флаг и заканчивает grace, `test-unlock` снимает флаг, `test-sleep` заканчивает grace (research R7)

## Phase 3: User Story 1 — агент работает при заблокированном экране (P1)

**Independent Test**: аренда A, затем `test-lock`. `secret run A` работает без Touch ID.
`secret run B` сразу даёт `not leased: B`.

- [x] T005 [US1] `helper/store/main.swift`: запрос `read` сначала смотрит таблицу аренды (та же ссылка `r` и срок не прошёл). Ответ получает поле источников `l`/`g` (research R6)
- [x] T006 [US1] `helper/store/main.swift`: при заблокированном экране имена вне аренды дают `err 6 not leased: A, B` без `confirmedContext` (FR-007)
- [x] T007 [US1] `helper/store/main.swift`: команда `read` пишет источники в stderr строкой `source: ...`. `bin/secret` в `run`/`get` пишет в журнал деталь `lease` для имён из аренды и не показывает эту строку (FR-009)

## Phase 4: User Story 2 — запрос аренды (P1)

**Independent Test**: `secret lease --for 1h A` с ответом «да» даёт аренду, с «нет» — ошибку без аренды.

<!-- утр-100: 4.2 — строки задач spec-kit: файл, действие и условия в одном пункте -->
- [x] T008 [US2] `helper/store/main.swift`: запрос агента `lease` — всегда новый `confirmedContext` с текстом из контракта, чтение названных значений, добавление в таблицу (поздний конец для повторного имени). Команда `lease SECONDS NAME...`. Ошибки при блокировке экрана и `SECRET_NO_DIALOG` (contracts/cli.md)
<!-- утр-100: 4.2 — строка задачи spec-kit: файл, действие и условия в одном пункте -->
- [x] T009 [US2] `bin/secret`: `cmd_lease` по contracts/cli.md: `--for`, имена или `-e FILE`. Проверка имён до окна, ошибка для файлового keychain, журнал `lease`. Строки `help` и `usage`
- [x] T010 [P] [US2] `hooks/claude-pretooluse.sh`: проверить, что хук пропускает `secret lease`, `secret lease status`, `secret lease --revoke`. Правку делать, только если хук их останавливает

## Phase 5: User Story 3 — конец аренды (P1)

**Independent Test**: `SECRET_TEST_MAX_LEASE=2`, через 3 секунды `not leased`. `--revoke`, `lock` и `set` заканчивают аренду.

- [x] T011 [US3] `helper/store/main.swift`: запрос `revoke` и команда `lease-revoke`. `bin/secret lease --revoke`, журнал `lease-revoke`
- [x] T012 [US3] `helper/store/main.swift`: имя выходит из аренды, если ссылка записи другая или записи нет (research R4). Проверка при чтении и в `lease-status`

## Phase 6: User Story 4 — статус, журнал, SecretBar (P2)

<!-- утр-100: 8.1 — строки задач spec-kit: файл, действие и условия в одном пункте -->
- [x] T013 [US4] `helper/store/main.swift`: запрос `lease-status`, команда `lease-status`; поле `lease=N:END` в строке `status` для SecretBar. `bin/secret lease status` по контракту
- [ ] T014 [US4] `app/SecretBar/`: строка активной аренды (число имён, конец) и кнопка «Revoke lease», вызов `bin/secret lease --revoke`. Перевод `ru` в `Localizable.xcstrings`

## Phase 7: Тесты и документы

<!-- утр-100: 4.2 — строки задач spec-kit: файл, действие и условия в одном пункте -->
- [x] T015 `tests/run.sh`: SC-001 (аренда после `test-lock`, `not leased` для другого имени меньше чем за 1 секунду, `test-sleep`), SC-002 (`SECRET_TEST_MAX_LEASE`), SC-003 (`--revoke`, `lock`, `set`, `rm`), SC-004 (`--for 25h`, отказ Touch ID, пустой `-e`), `lease status`, пометка `lease` в журнале, grace после `test-lock` заканчивается как раньше
- [x] T016 [P] `docs/claude-md-secrets.md`: правило для агента (FR-012)
- [x] T017 [P] `README.md`, `README.ru.md`, `site/`: команда `secret lease`
- [ ] T018 Ручная проверка SC-005: аренда агентом, Touch ID, блокировка экрана 30 минут, секрет из аренды и ошибка для другого. Запишите дату
- [ ] T019 Ручная проверка SC-006: аренда после сна Mac. Запишите дату
- [ ] T020 Ручная проверка SecretBar: строка аренды и отзыв. Запишите дату

## Dependencies

<!-- утр-100: 4.2 — цепочка зависимостей задач -->
T001 → T002 → T003 → T004 → (T005..T007) → (T008, T009) → (T011, T012) → T013 → T014 → T015.
T010, T016, T017 — после T009, параллельно. T018..T020 — после T015 и пересборки helper и SecretBar.

## Implementation Strategy

MVP — фазы 1–5: аренда из CLI, работа при блокировке, конец аренды. SecretBar (T014) идёт
следующим коммитом.
