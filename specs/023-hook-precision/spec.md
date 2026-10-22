# Feature Specification: хук без ложных срабатываний

**Feature Branch**: `023-hook-precision`. Работа идёт в `main`.

**Created**: 2026-10-22

**Status**: Done 2026-10-22

**Input**: Владелец: «поправь хуки где надо, чтоб я с новой версией работал хорошо». 2026-10-22 хук
трижды остановил безопасные команды агента:

- heredoc `cat > spec.md` с текстом «`secret touchid repair`» внутри.
- `codesign --verify` для helper хранилища.
- Правку `tests/run.sh` с именами тестовых переменных в тексте.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Текст в файл (Priority: P1)

1. **When** агент пишет текст через `cat > FILE <<EOF`, `tee FILE <<EOF` или `git commit -F - <<EOF`,
   **Then** хук не проверяет тело heredoc.
2. **When** тело heredoc идёт в `sh`, `bash`, `zsh` или другую программу, **Then** хук проверяет
   тело как команды.

### User Story 2 - Проверка helper без запуска (Priority: P1)

1. **When** команда только смотрит на файл helper (`codesign`, `ls`, `stat`, `file`, `shasum`,
   `xattr`, `spctl`), **Then** хук пропускает её.
2. **When** в той же части команды есть `$(` или обратная кавычка, **Then** хук блокирует её,
   как раньше.
3. Запуск helper под любым именем хук блокирует, как раньше.

## Requirements *(mandatory)*

- **FR-001**: хук вырезает тело heredoc у `cat`, `tee`, `git` перед проверкой.
- **FR-002**: правило helper хранилища пропускает части команды, которые начинаются с программы
  из списка чтения.
- **FR-003**: все прежние проверки `hook blocks` проходят.

## Success Criteria *(mandatory)*

- **SC-001**: три команды из Input проходят хук.
- **SC-002**: `tests/run.sh` проходит целиком.
