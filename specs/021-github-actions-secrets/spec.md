# Feature Specification: секрет в GitHub Actions

**Feature Branch**: `021-github-actions-secrets`. Работа идёт в `main`.

**Created**: 2026-10-22

**Status**: In progress

**Input**: Владелец: «чтоб наша софтина работала с GitHub-секретами». GitHub Actions secrets
принимают значение и не отдают его обратно. Владелец выбрал отправку значения из `secret` в GitHub.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Отправить секрет в репу (Priority: P1)

1. **When** человек или агент запускает `secret gh NAME -R owner/repo`, **Then** окно macOS
   спрашивает подтверждение. После «Send» команда записывает значение NAME в Actions secret
   `NAME` этой репы.
2. `secret gh NAME GH_NAME ...` даёт секрету в GitHub другое имя.
3. Флаги `-e ENV`, `-o ORG`, `-v VISIBILITY`, `-a APP` команда передаёт в `gh` без изменений.
4. Вывод и журнал содержат имена и цель, значения в них нет.

### User Story 2 - Без подтверждения нет отправки (Priority: P1)

1. **When** человек нажимает «Cancel» или окно закрыто для команды (`SECRET_NO_DIALOG=1`),
   **Then** команда выдаёт ошибку. `gh` она не вызывает.
2. Флаги `-b`, `--body`, `-f`, `--env-file` команда отклоняет: значение берётся только из NAME.

### Edge Cases

- `gh` нет: ошибка «gh not found» с подсказкой.
- NAME нет: ошибка «not found».
- GH_NAME с точкой или дефисом: ошибка, GitHub такие имена не принимает.

## Requirements *(mandatory)*

- **FR-001**: `secret gh NAME [GH_NAME] [флаги gh]` вызывает `gh secret set GH_NAME [флаги]`,
  значение идёт через stdin.
- **FR-002**: перед отправкой человек подтверждает её в окне.
- **FR-003**: журнал доступа пишет операцию `gh`, имя, цель.
- **FR-004**: хук Claude Code блокирует тестовые переменные `SECRET_GH` и `SECRET_CONFIRM`.

## Success Criteria *(mandatory)*

- **SC-001**: секрет попадает в Actions secrets одной командой и одним подтверждением.
- **SC-002**: значение не появляется в выводе, журнале, `argv` и тексте окна.

## Assumptions

- `gh` установлен, и человек выполнил `gh auth login`.
