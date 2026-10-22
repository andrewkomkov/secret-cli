# Feature Specification: Защита от утечек при работе агента

**Feature Branch**: `001-agent-safety` (работа идёт в `main` локальной репы)

**Created**: 2026-10-02

**Status**: Done — 2026-10-02

**Input**: Владелец хочет, чтобы агент мог создавать секреты, не видя значений, чтобы значения
не попадали в вывод команд, чтобы было видно, какие секреты брал агент, и чтобы запрет на
чтение значений держался не только на правиле в `CLAUDE.md`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Агент создаёт пароль, не видя его (Priority: P1)

Агенту нужен новый пароль, например для учётки БД. Он запускает одну команду, пароль
появляется в keychain, а в выводе есть только имя и длина.

**Independent Test**: `secret gen -l 24 NAME` — в keychain запись длиной 24, в выводе значения нет.

**Acceptance Scenarios**:

1. **Given** NAME нет, **When** `secret gen NAME`, **Then** в keychain запись из 32 символов
   `A-Za-z0-9`, вывод — `generated: NAME (32 chars)`.
2. **Given** NAME есть, **When** `secret gen NAME`, **Then** ошибка, старое значение осталось.
   С `-f` значение заменяется.
3. **When** `secret gen -s symbols NAME`, **Then** в значении есть и символы
   `!#%+-.=@^_~`, но нет кавычек, `\`, `$`, `` ` `` и пробела.

### User Story 2 - Значения не попадают в вывод (Priority: P1)

Агент запускает команду с секретами. Если команда печатает значение (`curl -v`, отладка),
вместо него в выводе `***`.

**Independent Test**: `secret run --mask NAME -- sh -c 'echo "$NAME"; echo "$NAME" >&2'` печатает
`***` в stdout и в stderr.

**Acceptance Scenarios**:

1. **Given** `--mask`, **When** команда печатает значение в stdout или stderr, **Then** там `***`.
2. **Given** `--mask`, **When** команда завершается с кодом N, **Then** `secret run` завершается с кодом N.
3. **Given** `SECRET_RUN_MASK=1`, **When** `secret run` без флага, **Then** маскировка включена.
4. **Given** `--mask` и `-e .env`, **Then** маскируются значения из ссылок `secret:`, а простые
   значения `.env` (порты, хосты) не маскируются.

### User Story 3 - Видно, какие секреты брали (Priority: P2)

Владелец смотрит, когда и какие секреты читались и кто читал: человек или агент.

**Independent Test**: после `secret get A` и `secret run B -- true` команда `secret log`
показывает две строки с временем, командой, именем и источником; значений в журнале нет.

**Acceptance Scenarios**:

1. **When** `get`, `run`, `copy`, `export` читают секрет, **Then** в журнал пишется строка:
   время, команда, имена, `agent` или `human`, родительский процесс.
2. **Given** `SECRET_LOG=off`, **Then** журнал не пишется.
3. **When** `secret log -n 5 NAME`, **Then** последние 5 строк про NAME.

### User Story 4 - Агенту нельзя читать значения в обход правил (Priority: P2)

Хук Claude Code останавливает команды, которые выводят значения: `secret get`,
`security find-generic-password -w`/`-g`, `security dump-keychain -d`, вывод `.env` через
`cat`/`less`/`head`/`tail`/`bat`, вывод окружения внутри `secret run` (`env`, `printenv`, `set`).

**Independent Test**: хуку на вход подаётся JSON с такой командой — код выхода 2 и причина в
stderr. Обычная команда (`secret run X -- psql`) — код 0.

### Edge Cases

- Значение секрета встречается внутри другого значения: маскируется более длинное первым.
- Команда в `--mask` печатает без перевода строки (прогресс): вывод появляется построчно.
- Журнал недоступен на запись: команда работает, в stderr предупреждение.
- Хук получает JSON без поля `command`: пропускает.

## Requirements *(mandatory)*

- **FR-001**: `secret gen [-c COMMENT] [-l LEN] [-s alnum|symbols|hex] [-f] NAME`. LEN от 8 до 256, по умолчанию 32.
- **FR-002**: Значение `gen` берётся из `/dev/urandom` и не печатается.
- **FR-003**: `secret run --mask` заменяет значения секретов на `***` в stdout и stderr команды и сохраняет её код выхода.
- **FR-004**: `SECRET_RUN_MASK=1` включает `--mask` по умолчанию.
- **FR-005**: Журнал `${SECRET_LOG:-~/.local/state/secret/access.log}`, права 600, без значений.
- **FR-006**: `secret log [-n N] [NAME]` печатает журнал.
- **FR-007**: Хук `hooks/claude-pretooluse.sh` для события PreToolUse инструмента Bash; `install.sh --claude-hook` добавляет его в `~/.claude/settings.json`.

## Success Criteria *(mandatory)*

- **SC-001**: В выводе `gen`, `run --mask`, `log` и в файле журнала нет ни одного значения секрета (проверяется тестом).
- **SC-002**: Хук блокирует все 8 шаблонов из US4 и пропускает 5 обычных команд из теста.
- **SC-003**: `tests/run.sh` проходит целиком.

## Assumptions

- Маскировка ловит значение как есть. Закодированное значение (base64 в `Authorization: Basic`,
  URL-кодирование) не ловится: это записано в README.
- Хук — защита от ошибки агента, а не от злого умысла: команду можно составить так, что шаблон
  её не узнает.
- `CLAUDECODE=1` в окружении означает запуск из Claude Code.
