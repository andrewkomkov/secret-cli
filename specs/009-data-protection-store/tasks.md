# Tasks: Хранилище data protection keychain

**Input**: `specs/009-data-protection-store/` (spec.md, plan.md, research.md, data-model.md,
contracts/helper-cli.md, quickstart.md)

Тесты входят в задачи: конституция (IV) требует проверки в `tests/run.sh` для каждой фичи.

## Phase 1: Проект Xcode и сборка

- [x] T001 Проект Xcode `helper/SecretStore.xcodeproj/project.pbxproj`: один таргет, конфигурации Release и Test (`SWIFT_ACTIVE_COMPILATION_CONDITIONS=SECRET_TEST`, bundle ID `$(SECRET_BUNDLE_ID)-test`), hardened runtime, `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO`. `helper/SecretStore.entitlements` с `$(AppIdentifierPrefix)$(PRODUCT_BUNDLE_IDENTIFIER)`
- [x] T002 Функция сборки в `install.sh`: Xcode (`DEVELOPER_DIR`), Team ID из `OU` сертификата Apple Development, `xcodebuild -allowProvisioningUpdates`. Функция атомарно заменяет `build/SecretStore.app`, `build/SecretStore.expires` и `build/SecretStore.src-sha256`. Без Xcode — сообщение и файловый режим

## Phase 2: Helper и выбор хранилища

- [x] T003 `helper/secret-store.swift`: запросы `SecItem*` (account, access group, атрибуты из data-model.md), `list`, `has`, `write` пакетом из stdin, `delete`, `profile`. Сборка `Test`: account и каталог состояния из окружения, записи без `.userPresence`, `wipe`
- [x] T004 `helper/secret-store.swift`: процесс-агент — сокет, проверка uid, `LAContext`, политика после Touch ID, grace ≤ 3600. Агент завершает работу по grace, по `lock` и после 30 с простоя. Клиент запускает агента через `posix_spawn` с `SETSID`, блокировка `flock` защищает от второго агента
- [x] T005 `helper/secret-store.swift`: `read`, `attrs`, `policy show|grace`, `lock` через агента. Флаг `--no-dialog`. Запись без `.userPresence` в рабочей сборке → код 4 `not protected`
- [x] T006 `bin/secret`: файл режима `~/.local/state/secret/store`, `STORE`. Переменные окружения переопределяют `STORE` только вместе с тестовым keychain. Ветки `dp` в `item_exists`, `list_items`, `read_values`, `write_item`, `set_attrs`, новая `delete_item` вместо прямых `security delete-generic-password`, `ensure_keychain`

## Phase 3: User Story 1 — секреты в новом хранилище (P1)

**Independent Test**: тестовая сборка: `migrate` переносит записи, команды дают прежний результат.

<!-- утр-100: 1.9, E1.9 — метки US заданы шаблоном spec-kit -->
- [x] T007 [US1] `bin/secret`: `import` и `restore` пакетом через `write` helper в режиме `dp`
- [x] T008 [US1] `bin/secret`: `secret migrate --backup FILE [--pass-stdin]`. Шаги: `export`, чтение старых значений, запись в новое хранилище, политика, сверка, файл режима, удаление старых копий из файлового keychain. При ошибке команда не меняет режим
<!-- утр-100: 1.9, E1.9 — метки SC заданы шаблоном spec-kit -->
- [x] T009 [US1] `tests/run.sh`: сборка `Test` в `build/test/`, кэш по хэшу исходника. Без Xcode — пропуск с сообщением. `migrate` и все команды в режиме `dp` (SC-001, SC-002). Удаление записей прогона

## Phase 4: User Story 2 — значение только после Touch ID (P1)

- [x] T010 [US2] `tests/run.sh`: один вопрос на `get`, `run` с несколькими именами, `export`. `SECRET_NO_DIALOG=1` и отказ — ошибка без вывода. `ls`, `has`, `check`, `set`, `rm` без вопроса
- [x] T011 [US2] Ручная проверка SC-004, 2026-10-07. После `secret lock` проба с подписью той же Personal Team и с access group рабочего хранилища читает атрибуты записи (`0`). Чтение значения даёт `-25308`, проба не получает значение. Окна Touch ID при `migrate` и `run` видел владелец

## Phase 5: User Story 4 — продление profile (P1)

- [x] T012 [US4] `install.sh --renew`: пересборка, если до конца срока меньше 3 дней или изменился исходник. Удаление старого profile этого bundle ID. При ошибке — сообщение про вход в Xcode
- [x] T013 [US4] `install.sh --launchd`: `~/Library/LaunchAgents/secretcli.renew.plist`, раз в день и при входе, журнал `~/.local/state/secret/renew.log`
- [x] T014 [US4] `bin/secret`: предупреждение в stderr, если до конца срока profile меньше 2 дней или срок истёк. Ошибка с подсказкой, если helper не запускается
- [x] T015 [US4] `tests/run.sh`: предупреждение о сроке по подставленному файлу срока
- [x] T016 [US4] Ручная проверка: продление через LaunchAgent даёт новый срок. Проверка 2026-10-07: срок в `build/SecretStore.expires` подставлен на сутки вперёд. `launchctl kickstart gui/$UID/secretcli.renew` удалил profile, Xcode выдал новый до 2026-10-14 13:57 (был 13:52). Настоящее истечение срока не дожидались

## Phase 6: User Story 3 — grace (P2)

- [x] T017 [US3] `bin/secret`: `touchid status|grace|on|off`, `lock`, `unlock`, `init` в режиме `dp`
- [x] T018 [US3] `tests/run.sh`: две команды в grace — один вопрос. `lock` — новый вопрос. Grace 0 — вопрос каждый раз. Grace > 3600 — ошибка. `touchid off` — ошибка (SC-003)

## Phase 7: User Story 5 — обратный переезд (P3)

- [x] T019 [US5] `bin/secret`: `secret migrate --back`: чтение из нового хранилища, запись в файловый keychain, сверка, удаление файла режима и записей нового хранилища
- [x] T020 [US5] `tests/run.sh`: `migrate --back` сохраняет значения, комментарии, сроки

## Phase 8: Хук, документы, замеры

- [x] T021 [P] `hooks/claude-pretooluse.sh`: переменные `SECRET_STORE_*`, `SECRET_TEST_*` и прямой вызов `SecretStore` агентом. Тесты хука
- [x] T022 [P] `README.md`, `docs/claude-md-secrets.md`, раздел Secrets в `~/.claude/CLAUDE.md`, `usage` в `bin/secret`, `completions/_secret` (`migrate`)
- [x] T023 Сборка Release без предупреждений об устаревшем API (SC-006): `xcodebuild` Release — 0 строк `deprecat`, 2026-10-07
- [x] T024 `tests/run.sh` целиком: 262 проверки, 2026-10-07. Замер на 300 записях (`N=300` и `DP=1 N=300 tests/bench.sh`):

  | Команда | файловый keychain | data protection |
  |---|---|---|
  | `import` 300 значений | 4,67 с | 4,04 с |
  | `ls -l` | 0,07 с | 0,09 с |
  | `run` 5 ссылок | 0,19 с | 0,17 с |
  | `check` 300 ключей | 0,59 с | 0,65 с |
  | `set` | 0,14 с | 0,15 с |
  | `get` | 0,09 с | 0,09 с |
- [x] T025 Ручная проверка SC-005, 2026-10-07. `secret migrate --backup ~/secrets-before-dp-2026-10-07.bak` — 49 секретов в новом хранилище, в `secrets.keychain-db` 0 записей. `ls` — 49 имён без Touch ID. `run` с одной ссылкой работает. `touchid status` — `store: data protection keychain`. LaunchAgent `secretcli.renew` стоит (T013, T016). Первая попытка с паролем копии короче 12 символов ничего не изменила и выявила ошибку `export`. Ошибка исправлена, тест есть

## Dependencies

<!-- утр-100: 4.2, 1.9, E4.2, E1.9 — цепочка зависимостей задач, метки US заданы шаблоном spec-kit -->
T001 → T002 → T003 → T004 → T005 → T006 → US1 (T007–T009) → US2, US4, US3, US5 → Polish.
US2, US4, US3, US5 зависят только от Phase 2 и US1.

## Parallel

T021 и T022 — разные файлы. T012–T013 (`install.sh`) идут параллельно с T017 (`bin/secret`).

<!-- ste: E1.1 — заголовок задан шаблоном spec-kit -->
## Implementation Strategy

Минимальная рабочая версия (MVP) — Phase 1–4 и US4. Без продления helper через неделю перестанет
запускаться. Затем grace,
обратный переезд, документы. Перенос рабочего keychain (T025) — последним, после всех тестов.
