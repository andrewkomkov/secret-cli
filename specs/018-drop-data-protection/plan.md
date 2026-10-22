# Implementation Plan: удалить хранилище data protection

**Spec**: `specs/018-drop-data-protection/spec.md`

## Technical Context

Порядок важен: удалить записи может только helper data protection, поэтому сначала удаление,
потом код.

1. `helper/store/main.swift`: команда `drop` в сборке data protection. Touch ID, затем
   `SecItemDelete` для account `secret-cli` и `secret-cli.meta`. `bin/secret`:
   `migrate --drop-dp` — режим `vault`, сверка имён, вызов `drop`. Сборка, запуск у владельца.
2. Код: `main.swift` только для хранилища Secure Enclave, без `#if VAULT`. Сборка
   `helper/store/build.sh` (`swiftc`), бинарник `build/secret-vault`. Удалить проект Xcode,
   entitlements, `build-vault.sh`.
3. `bin/secret`: режим `vault` или файловый keychain. `STORE` — всегда helper Secure Enclave.
   `migrate --backup FILE` — в Secure Enclave, `--back` — в файловый keychain. Флаги `--vault`,
   `--dp`, `--drop-dp`, переменные `SECRET_STORE_HELPER`, `SECRET_STORE_EXPIRES` уходят.
   Режим `dp` в файле режима — ошибка с подсказкой.
4. `install.sh`: без `--renew` и `--launchd`. Снимает старый LaunchAgent и удаляет
   `build/SecretStore*`.
5. SecretBar: без profile, `renew`, уведомления о подписи. Хранилище — режим `vault`.
6. Тесты: раздел data protection уходит. Проверки 010, 011, 014 переходят в раздел 017.
   Переезд из файлового keychain — на тестовой сборке Secure Enclave.
7. Конституция 2.0.0 (MAJOR): хранилище data protection удалено.
8. Чистка на Mac владельца: LaunchAgent, profile `secretcli.*.store`, `build/SecretStore*`,
   `build/test/SecretStoreTest*`, файлы агента `agent.sock`, `agent.lock`, `renew.log`.

## Constitution Check

- I, II: без изменений для хранилища Secure Enclave.
- III: profile и Personal Team больше не нужны.
- V: команды прежние, кроме `migrate --vault` и `--dp` из 017. Они жили один день и нужны были
  только для переезда.

## Complexity Tracking

Удаление флагов `migrate --vault` и `--dp` — отступление от V: хранилища data protection
больше нет.
