# Feature Specification: Меньше вызовов keychain

**Feature Branch**: `008-fewer-keychain-calls` (работа идёт в `main` локальной репы)

**Created**: 2026-10-02

**Status**: Done — 2026-10-02

**Input**: Владелец просил убрать лишние вызовы `security`. Замер 2026-10-02 на временном
keychain (`tests/bench.sh`, `N=300`):

| Команда | 40 записей | 300 записей |
|---|---|---|
| `import` всех значений | 4,1 с | 33,8 с |
| `check` .env на все ключи | 0,8 с | 6,1 с |
| `ls -l` | 0,11 с | 0,44 с |
| `run` с 5 ссылками | 0,22 с | 0,22 с |
| `set` одного значения | 0,12 с | 0,17 с |
| `get` | 0,08 с | 0,13 с |

`import` растёт как n²: после каждой записи `refresh_names` читает весь keychain. `check` на
каждый ключ вызывает `security` два раза: наличие и срок.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Быстрый import и check (Priority: P1)

**Acceptance Scenarios**:

1. **Given** 300 записей, **When** `import` 300 значений, **Then** время растёт линейно: не больше 15 с.
2. **Given** 300 записей, **When** `check` на 300 ключей, **Then** не больше 1 с.
3. **Then** остальные команды не медленнее, чем в таблице.

## Requirements *(mandatory)*

- **FR-001**: Атрибуты всех записей (имя, комментарий, срок) команда читает одним `dump-keychain` и держит в памяти до первой записи в keychain.
- **FR-002**: `import`, `restore`, перенос в `touchid on/off` и `__rehelper` обновляют кэш имён один раз в конце.
- **FR-003**: Проверка после записи (`item_exists` в `set`) идёт прямым запросом, без чтения всего keychain.

## Success Criteria *(mandatory)*

- **SC-001**: Замер на 300 записях до и после записан в `tasks.md`.
- **SC-002**: `tests/run.sh` проходит целиком.
