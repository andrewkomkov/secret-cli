# Feature Specification: удалить хранилище data protection

**Feature Branch**: `018-drop-data-protection`. Работа идёт в `main` локальной репы.

**Created**: 2026-10-14

**Status**: Done 2026-10-14

**Input**: Владелец переехал в хранилище Secure Enclave (017) и попросил удалить старое
хранилище data protection. Всё должно остаться в рабочем виде на его Mac.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Старых копий нет (Priority: P1)

1. **When** агент запускает `secret migrate --drop-dp`, **Then** команда сверяет имена: каждое
   имя хранилища data protection есть в хранилище Secure Enclave. Потом helper спрашивает
   Touch ID и удаляет все свои записи: значения, служебные записи, политику.
2. Команда работает только в режиме `vault`. В другом режиме команда выдаёт ошибку и
   сохраняет записи.

### User Story 2 - Проект без data protection (Priority: P1)

1. В репе нет проекта Xcode helper, entitlements и сборки с profile. Xcode нужен только для
   SecretBar.
2. `install.sh` не продлевает profile. Если LaunchAgent `secretcli.renew` есть, `install.sh`
   его снимает.
3. SecretBar не показывает подпись helper и кнопку продления.
4. `secret migrate --backup FILE` переносит файловый keychain в хранилище Secure Enclave.
   `secret migrate --back` возвращает секреты в файловый keychain.
5. README, правила агента и конституция описывают два хранилища: Secure Enclave и файловый
   keychain.

### User Story 3 - Тестов не меньше (Priority: P1)

Проверки grace (простой, предел, блокировка, память), буфера обмена и `status` идут на тестовой
сборке helper Secure Enclave.

## Requirements *(mandatory)*

- **FR-001**: `secret migrate --drop-dp` удаляет хранилище data protection после сверки имён и
  Touch ID.
- **FR-002**: в коде нет хранилища data protection и provisioning profile.
- **FR-003**: на Mac владельца нет LaunchAgent продления, сборок `SecretStore.app` и profile
  bundle `secretcli.*.store`.
- **FR-004**: `tests/run.sh` проходит, тесты 009, 010, 011, 014 перенесены.

## Success Criteria *(mandatory)*

- **SC-001**: хранилище data protection пусто.
- **SC-002**: на Mac владельца `secret`, SecretBar, ⌥⌘S и Spotlight работают с хранилищем
  Secure Enclave.
- **SC-003**: `tests/run.sh` проходит целиком.

## Assumptions

- Profile helper data protection действует до 2026-10-19. До этой даты helper ещё запускается
  и может удалить свои записи.
