<!-- ste: E1.1 — заголовок задан шаблоном spec-kit -->
# Implementation Plan: Скользящий grace

**Branch**: `010-sliding-grace` | **Date**: 2026-10-07 | **Spec**: [spec.md](spec.md)

## Summary <!-- slop: заголовок задан шаблоном spec-kit -->

Агент helper `SecretStore` продлевает grace после каждого запроса: конец grace — сейчас плюс
простой. Предел — 8 часов от Touch ID. Блокировку экрана агент видит по уведомлению и по
опросу состояния сессии. Сон Mac агент видит по разнице часов с учётом сна и без него. Тогда агент
закрывает контекст и завершается. Клиент повторяет запрос, если агент закрыл соединение без
ответа. Цикл агента переходит с `poll` на
`RunLoop` главного потока: уведомлениям нужен `RunLoop`.

## Technical Context

**Language and version**: Swift 6.4 в режиме Swift 5, bash 3.2.

**Primary Dependencies**: Foundation (`DistributedNotificationCenter`), CoreGraphics
(`CGSessionCopyCurrentDictionary`), LocalAuthentication.

**Storage**: политика `__secret-cli.policy`, вид `v1 grace=N` без изменений.

**Testing**: `tests/run.sh` на тестовой сборке. Предел — переменная `SECRET_TEST_MAX_GRACE`.
Сигнал блокировки — команда `test-lock` тестовой сборки, она шлёт своё уведомление.

**Constraints**: монотонные часы для предела (`CLOCK_MONOTONIC`, идут и во сне Mac).

## Constitution Check

| Принцип | Как соблюдается |
|---|---|
| I | без изменений |
| II | простой ≤ 3600, предел 8 часов, блокировка экрана, сон и `lock` заканчивают grace (1.2.0) |
| III | CoreGraphics входит в macOS |
| IV | тестовая сборка, `test-lock` и `SECRET_TEST_MAX_GRACE` только в ней |
| V | `touchid grace N` и вид политики прежние; N теперь — простой (отступление) |

## Project Structure

```text
helper/store/main.swift   # агент: RunLoop, скользящий конец grace, уведомления, status
bin/secret                # touchid status: простой, предел, остаток grace
tests/run.sh              # SC-001..SC-003
```

## Complexity Tracking

| Отступление | Причина |
|---|---|
| `touchid grace N` задаёт простой, а не время от Touch ID (V) | так попросил владелец; блокировка экрана и сон ограничивают grace |
| По умолчанию 1800 вместо 300 | владелец выбрал 30 минут простоя |
