# Feature Specification: Маскировка для агента по умолчанию

**Feature Branch**: `006-agent-auto-mask` (работа идёт в `main` локальной репы)

**Created**: 2026-10-02

**Status**: Done — 2026-10-02

**Input**: Сейчас `--mask` держится на правиле в `CLAUDE.md`: если агент не напишет флаг,
значение уйдёт в вывод. Ещё маскировка не ловит закодированное значение.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Агент не может забыть `--mask` (Priority: P1)

**Acceptance Scenarios**:

1. **Given** `CLAUDECODE=1`, **When** `secret run NAME -- cmd` без `--mask`, **Then** вывод маскируется.
2. **Given** `CLAUDECODE=1`, **When** `secret run --no-mask ...`, **Then** маскировка остаётся, в stderr предупреждение.
3. **Given** человек без `CLAUDECODE`, **When** `--no-mask` или без флага, **Then** вывод без маскировки, как раньше.
4. **Given** `CLAUDECODE=1`, **When** cmd печатает всё окружение (`python3 -c 'print(os.environ)'`), **Then** значения секретов в выводе — `***`.

### User Story 2 - Закодированное значение (Priority: P2)

**Acceptance Scenarios**:

1. **When** cmd печатает значение в base64 или с URL-кодированием, **Then** вместо него `***`.

### Edge Cases

- Значение короче 8 символов: base64 и URL-варианты не маскируются, чтобы не заменять случайные куски текста. Само значение маскируется.
- URL-вариант совпадает со значением (нет символов для кодирования): одна замена.

## Requirements *(mandatory)*

- **FR-001**: `CLAUDECODE` непустой → `run` всегда с маскировкой; `--no-mask` в этом случае даёт предупреждение.
- **FR-002**: `--no-mask` для человека отключает `SECRET_RUN_MASK=1`.
- **FR-003**: Маскировщик заменяет значение, его base64 (стандартный и URL-safe, с `=` и без) и URL-кодирование.

## Success Criteria *(mandatory)*

- **SC-001**: Тест: под `CLAUDECODE=1` вывод окружения через `python3`/`env` не содержит значений.
- **SC-002**: `tests/run.sh` проходит целиком.

## Assumptions

- `base64(user:pass)` в `Authorization: Basic` не ловится: в нём другое значение. Это записано в README.
- Агент может запустить команду без `CLAUDECODE` (`env -u CLAUDECODE`). Фича защищает от ошибки, не от умысла.
