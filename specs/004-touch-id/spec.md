# Feature Specification: Touch ID

**Feature Branch**: `004-touch-id` (работа идёт в `main` локальной репы)

**Created**: 2026-10-02

**Status**: In progress — всё, кроме ручной проверки Touch ID (T009), сделано 2026-10-02

**Input**: Владелец хочет подтверждать пальцем каждое использование секрета: пока keychain
разблокирован, команда сейчас отдаёт значения без вопросов. Ещё нужно, чтобы проверка
статуса keychain не открывала системное окно пароля: 2026-10-02 тесты открыли его много раз.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Подтверждение пальцем (Priority: P1)

**Acceptance Scenarios**:

1. **Given** `secret touchid on`, **When** `get`, `copy`, `run` или `export`, **Then** macOS
   спрашивает Touch ID (или пароль Mac) с текстом, какие секреты и для какой команды.
2. **Given** подтверждение было меньше 300 с назад, **Then** повторного вопроса нет. Время
   задаёт `secret touchid grace N`, `0` — спрашивать каждый раз.
3. **Given** отказ или отмена, **Then** команда завершается с ошибкой, значение не читается.
4. **Given** `touchid off` (по умолчанию), **Then** команда работает как раньше.
5. **When** `secret touchid off` или `grace` при включённом Touch ID, **Then** нужно свежее подтверждение.
6. **When** `secret touchid status`, **Then** видно `on`/`off`, время и собран ли helper.

### User Story 2 - Статус keychain без окна (Priority: P1)

**Acceptance Scenarios**:

1. **Given** helper собран и keychain заблокирован, **When** любая команда, **Then** системное
   окно `security wants to use the keychain` не появляется: команда сама спрашивает пароль
   (терминал или своё окно) или с `SECRET_NO_DIALOG=1` завершается с ошибкой.

### Edge Cases

- Touch ID включён, а helper не собран: команда завершается с ошибкой, а не пропускает проверку.
- На Mac без Touch ID helper спрашивает пароль Mac.
- Агент меняет конфиг или файл отметки времени в обход команды: хук Claude Code блокирует такие команды.

## Requirements *(mandatory)*

- **FR-001**: `helper/secret-auth.swift`: `auth REASON` (LocalAuthentication, `deviceOwnerAuthentication`) и `status KEYCHAIN` (`SecKeychainGetStatus`).
- **FR-002**: `install.sh` собирает helper в `build/secret-auth` через `swiftc`; без `swiftc` — предупреждение.
- **FR-003**: `secret touchid on|off|status|grace N`; конфиг `~/.config/secret/config` (`touchid=`, `touchid_grace=`), права 600.
- **FR-004**: Отметка времени последнего подтверждения — файл `~/.local/state/secret/touchid-ok`, права 600.
- **FR-005**: Подмена helper, конфига и отметки (`SECRET_AUTH_HELPER`, `SECRET_CONFIG`, `SECRET_AUTH_STAMP`) и буфера обмена работает только с keychain, у которого другой inode, чем у keychain по умолчанию.
- **FR-006**: `is_unlocked` через `secret-auth status`, если helper собран.
- **FR-007**: Хук блокирует `secret touchid off|grace`, упоминание `.config/secret/` и `touchid-ok`, переменные `SECRET_AUTH_HELPER=`, `SECRET_CONFIG=`, `SECRET_AUTH_STAMP=`.

## Success Criteria *(mandatory)*

- **SC-001**: С заглушкой helper тесты проверяют: вопрос есть при `on`, нет при `off`, отказ останавливает команду, grace работает.
- **SC-002**: Тест блокирует временный keychain и проверяет команды на нём; системное окно не появляется (ручная проверка при первом прогоне).
- **SC-003**: Touch ID на Mac владельца: `get` с подтверждением и с отказом (ручная проверка).

## Assumptions

- Touch ID защищает команду `secret`. Процесс, который вызывает `security` напрямую, его
  обходит: записи создаёт `/usr/bin/security`, и он читает их без вопросов, пока keychain
  разблокирован. Типичные такие команды агента останавливает хук (фича 001).
- Отметку времени может подделать любой процесс пользователя. Это ограничение записано в README.
