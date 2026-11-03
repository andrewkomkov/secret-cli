<!-- ste: E1.1 — заголовок задан шаблоном spec-kit -->
# Implementation Plan: Аренда секретов для агентов

**Branch**: `026-agent-lease` | **Date**: 2026-11-03 | **Spec**: [spec.md](spec.md)

## Summary <!-- slop: заголовок задан шаблоном spec-kit -->

Аренду держит тот же процесс-агент helper `secret-vault`, что и grace. Агент получает новый
запрос `lease`: новый Touch ID, чтение названных значений, запись в таблицу аренды с концом
срока. Блокировка экрана и сон Mac теперь заканчивают только grace: агент закрывает контекст и
очищает кэш grace. Если аренда есть, агент продолжает работу. Если аренды нет, агент
завершается, как раньше.

При заблокированном экране агент отвечает на чтение только из таблицы аренды, для других имён —
ошибка `not leased`. `bin/secret` получает команду
`lease`, пометку `lease` в журнале и строку статуса для SecretBar.

## Technical Context

**Language and version**: Swift 6.4 в режиме Swift 5, bash 3.2, SwiftUI для SecretBar.

**Primary Dependencies**: те же, что в 010: Foundation, CoreGraphics, LocalAuthentication.

**Storage**: аренда живёт только в памяти агента. На диск она не идёт: перезагрузка и выход из
системы заканчивают процесс и аренду.

**Testing**: `tests/run.sh` на тестовой сборке. Предел аренды — `SECRET_TEST_MAX_LEASE`.
Блокировка экрана — `test-lock`: в тестовой сборке он ставит состояние «экран заблокирован»
у агента. `test-unlock` снимает его. Сон — `test-sleep`.

**Constraints**: срок аренды по `CLOCK_MONOTONIC` (идёт во сне). Хардкод предела 24 часа в
рабочей сборке.

## Constitution Check

| Принцип | Как соблюдается |
|---|---|
| I | значения аренды только в памяти агента, наружу — как в `read`; `lease status` даёт только имена |
| II | каждая аренда — новый Touch ID с именами и сроком в окне; предел 24 часа; `lock` заканчивает аренду. Блокировка и сон аренду оставляют — **правка принципа II** (2.4.0) |
| III | новых зависимостей нет |
| IV | тестовая сборка: `test-lock`, `test-unlock`, `test-sleep`, `SECRET_TEST_MAX_LEASE` |
| V | новая команда `lease`; `read`, `lock`, `touchid status` и grace без изменений для владельца |

Gate: правка II допустима только отдельным коммитом конституции до кода (Governance).

## Project Structure

```text
.specify/memory/constitution.md   # II: правило аренды, версия 2.4.0
helper/store/main.swift           # агент: таблица аренды, запросы lease / lease-status / revoke,
                                  # lock и сон заканчивают только grace
bin/secret                        # cmd_lease, журнал lease, help
hooks/claude-pretooluse.sh        # проверка: lease не остановлен (правило не нужно, тест нужен)
app/SecretBar/                    # строка аренды и кнопка отзыва, ru в Localizable.xcstrings
docs/claude-md-secrets.md         # правило для агента
README.md, README.ru.md, site/    # описание команды
tests/run.sh                      # SC-001..SC-004
```

Детали: [research.md](research.md), [contracts/cli.md](contracts/cli.md),
[data-model.md](data-model.md), [quickstart.md](quickstart.md).

## Complexity Tracking

| Отступление | Причина |
|---|---|
| Блокировка экрана и сон оставляют аренду (II) | так решил владелец 2026-11-03: агенты работают без владельца. Ограничения: явный список, Touch ID на каждую аренду, 24 часа, `lock` |
| Срок до 24 часов при пределе grace 8 часов (II) | решение владельца: ночная работа агента |
| Агент живёт после блокировки экрана, если есть аренда | раньше агент завершался; теперь завершается только при отсутствии аренды |
