# Feature Specification: Удобство каждый день

**Feature Branch**: `002-daily-use` (работа идёт в `main` локальной репы)

**Created**: 2026-10-02

**Status**: In progress — всё, кроме ручной проверки Tab (T012), сделано 2026-10-02

**Input**: Владелец хочет быстро вставлять пароль руками, дописывать имена по Tab,
переименовывать секреты и видеть токены, у которых кончается срок.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Пароль в буфер обмена (Priority: P1)

Владельцу нужно вставить пароль в форму входа. Он копирует его одной командой, через 30
секунд буфер очищается.

**Acceptance Scenarios**:

1. **When** `secret copy NAME`, **Then** значение в буфере, вывод — `copied: NAME (clears in 30s)`, значения в выводе нет.
2. **Given** прошло 30 с и в буфере то же значение, **Then** буфер пуст.
3. **Given** за 30 с владелец скопировал другой текст, **Then** этот текст остаётся.
4. **When** `secret copy NAME 5`, **Then** буфер очищается через 5 с.

### User Story 2 - Имена по Tab (Priority: P2)

**Acceptance Scenarios**:

1. **When** в zsh `secret <Tab>`, **Then** список команд.
2. **When** `secret run --mask CH_EX<Tab>`, **Then** имена секретов с этим началом.
3. **Given** keychain заблокирован, **When** Tab, **Then** имена берутся из кэша, окно пароля не открывается.

### User Story 3 - Переименование (Priority: P2)

**Acceptance Scenarios**:

1. **When** `secret mv OLD NEW`, **Then** NEW со значением, комментарием и сроком OLD, OLD удалён.
2. **Given** NEW есть, **Then** ошибка, обе записи без изменений. С `-f` NEW заменяется.
3. **Then** вывод напоминает обновить ссылки `secret:OLD`.

### User Story 4 - Срок жизни (Priority: P2)

**Acceptance Scenarios**:

1. **When** `secret set -x 2026-12-31 NAME` или `secret expire NAME 2026-12-31`, **Then** срок сохранён; `secret expire NAME none` убирает его.
2. **When** `secret ls --expiring [DAYS]` (по умолчанию 30), **Then** список истёкших и тех, что истекают за DAYS дней, с датой.
3. **Given** у секрета истёк срок, **When** `run` или `check` его используют, **Then** в stderr предупреждение, команда работает.
4. **When** `secret ls -l`, **Then** у секрета со сроком видна дата.

### Edge Cases

- Неверная дата (`2026-13-01`) — ошибка.
- `copy` в окружении без буфера обмена (нет `pbcopy`) — ошибка.
- Кэш имён отсутствует — Tab ничего не предлагает, ошибки нет.

## Requirements *(mandatory)*

- **FR-001**: `secret copy NAME [SECONDS]`, по умолчанию 30; фоновый процесс хранит только хэш значения.
- **FR-002**: `copy` пишет строку в журнал доступа.
- **FR-003**: Файл `completions/_secret` для zsh; `install.sh` ставит его в `$ZSH_CUSTOM/completions`.
- **FR-004**: Кэш имён `~/.local/state/secret/names` (права 600) обновляется после `ls`, `set`, `gen`, `rm`, `mv`.
- **FR-005**: `secret mv [-f] OLD NEW`.
- **FR-006**: Срок хранится в атрибуте `gena` записи как `expires=YYYY-MM-DD`; `set -x DATE`, `secret expire NAME DATE|none`.
- **FR-007**: `secret ls --expiring [DAYS]`; предупреждение в `run` и `check`.

## Success Criteria *(mandatory)*

- **SC-001**: В выводе `copy` и в кэше имён нет значений (тест).
- **SC-002**: `tests/run.sh` проходит целиком и не трогает буфер обмена владельца.

## Assumptions

- Менеджеры буфера обмена (Raycast, Alfred) могут сохранить скопированное значение в истории.
  Пометить запись как скрытую (`org.nspasteboard.ConcealedType`) `pbcopy` не умеет. Это записано в README.
- Имена секретов не считаются секретом: их можно держать в кэше.
