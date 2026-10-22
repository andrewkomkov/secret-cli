# Tasks: хранилище Secure Enclave без срока подписи

**Input**: `specs/017-secure-enclave-store/spec.md`

- [x] T001 [US1] `helper/store/main.swift`: хранение в файле под флагом `VAULT`, ключи, ECIES,
  подтверждение через `check`
- [x] T002 [US1] `helper/store/build-vault.sh`, `install.sh`: сборка `swiftc`, подпись
- [x] T003 [US1] `bin/secret`: режим `vault`, выбор helper, `touchid status`, без profile
- [x] T004 [US2] `bin/secret`: `migrate --vault`, `--dp`, `--back` из нового хранилища
- [x] T005 [US1] `app/SecretBar`: режим `vault`, helper по режиму, без предупреждения о profile
- [x] T006 [US3] `tests/run.sh`: тесты нового хранилища на тестовой сборке
- [x] T010 [US3] `helper/store/main.swift`, `bin/secret`, `tests/run.sh`: защита записи
  keychain (молчаливое чтение, `touchid repair`, grace в записи, проверка `.userPresence`)
- [x] T007 `README.md`, `docs/claude-md-secrets.md`, `~/.claude/CLAUDE.md`: новое хранилище
- [x] T008 Живая проверка 2026-10-14 на release-сборке с подписью Apple Development. В
  хранилище была только запись `LIVE_CHECK_017`, потом агент её удалил.
  - Новое хранилище: ключ Secure Enclave и запись keychain входа создаются без окна.
  - Чтение: одно окно, значение совпало. Второе чтение в grace: 0 с, без окна.
  - Пересборка helper: запись keychain читается без вопроса.
  - ACL записи: `decrypt` без пароля только для `secret-vault` по требованию подписи.
  - Другая программа перезаписала запись. Первая версия показала окно пароля keychain, владелец
    нажал «Отмена». После `SecKeychainSetUserInteractionAllowed(false)` helper отказывает за 0 с,
    окна нет.
  - `repair`: одно окно, новая запись, значение читается.
- [x] T009 Переезд владельца 2026-10-14: `secret migrate --vault` — 68 секретов, два окна, каждое
  значение сверено (SC-001). `secret run` с двумя именами в grace — 0 окон (SC-002).
  `touchid status`: `store: secure enclave`, без profile. SecretBar берёт статус у нового
  helper (значок открыт при grace), Spotlight — 68 записей. SC-003 (работа после 19 октября)
  проверится сам: helper без profile.
