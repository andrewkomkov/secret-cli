# Feature Specification: push формулы tap по SSH deploy key

**Feature Branch**: `028-tap-deploy-key`. Работа идёт в `main`.

**Created**: 2026-11-03

**Status**: Draft 2026-11-03

**Input**: Владелец выбрал SSH deploy key вместо PAT: «да давай через ssh». GitHub не выдаёт PAT
через API, а deploy key можно завести целиком из CLI. Цель — вернуть авто-обновление формулы в
tap при релизе, без токена из браузера.

## Контекст и границы

- Джоба `formula` в `.github/workflows/release.yml` клонирует tap по HTTPS с токеном
  `HOMEBREW_TAP_TOKEN`. Сейчас секрет отсутствует, и джоба пропускает обновление.
- Новый путь: ключ deploy key с правом записи на `andrewkomkov/homebrew-secret`. Публичная часть —
  в tap, приватная — в хранилище и в GitHub Actions.
- Приватный ключ PEM многострочный, а хранилище держит однострочные значения. Поэтому ключ едет в
  base64: одна строка в хранилище и в Actions, а workflow декодирует его обратно.
- Фича меняет только джобу `formula`. Сборка формулы (`def install`) и команды `secret` прежние.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - релиз обновляет tap по SSH (Priority: P1)

1. **When** release-please создаёт релиз и секрет `HOMEBREW_TAP_DEPLOY_KEY` задан, **Then** джоба
   `formula` клонирует tap по SSH ключом deploy key, правит `url` и `sha256`, коммитит и пушит.
2. **When** секрет пуст, **Then** джоба печатает warning и обновление пропускает, как сейчас.
3. **When** ключ без права записи, **Then** `git push` падает, джоба краснеет — молчания нет.

### User Story 2 - провиженинг ключа из CLI (Priority: P1)

1. **When** владелец заводит ключ, **Then** `ssh-keygen` создаёт пару ed25519 без пароля,
   `gh repo deploy-key add --allow-write` кладёт публичную часть в tap.
2. **When** ключ готов, **Then** base64 приватной части лежит в хранилище под
   `HOMEBREW_TAP_DEPLOY_KEY`, а `secret gh` отправляет её в Actions репозитория `secret-cli`.
3. Локальные файлы ключа удаляются после провиженинга. Приватный ключ в stdout и логи не идёт.

## Requirements *(mandatory)*

- **FR-001**: джоба `formula` использует SSH deploy key вместо HTTPS-токена. Env-переменная —
  `HOMEBREW_TAP_DEPLOY_KEY` (base64 приватного ключа).
- **FR-002**: шаги джобы — декодировать ключ в `~/.ssh`, добавить `github.com` в `known_hosts`,
  задать `GIT_SSH_COMMAND`, клонировать `git@github.com:andrewkomkov/homebrew-secret.git`, править
  формулу, коммитить и пушить.
- **FR-003**: ветка «нет ключа» печатает warning и выходит, обновление не делает.
- **FR-004**: deploy key имеет право записи только на `andrewkomkov/homebrew-secret`.
- **FR-005**: приватный ключ в хранилище и в Actions хранится как base64. Значение в argv и логи
  не идёт.

## Success Criteria *(mandatory)*

- **SC-001**: следующий релиз обновляет `url` и `sha256` в tap без ручной правки.
- **SC-002**: провиженинг ключа проходит целиком из CLI, без браузера.
- **SC-003**: приватный ключ остаётся вне stdout и логов; `gh secret list` показывает только имя.
