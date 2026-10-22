# Implementation Plan: SecretBar — индекс Spotlight восстанавливается сам

**Spec**: `specs/016-spotlight-self-heal/spec.md`

## Technical Context

SwiftUI, macOS 26, `app/SecretBar`.

- `SpotlightIndex.count() async -> Int?`: `CSSearchQuery` с `kMDItemDisplayName == "*"` по
  индексу своего bundle. При ошибке она возвращает `nil`. Её используют `--spotlight-check`
  и `Store`.
- `Store.healSpotlight()`: если Spotlight включён, секреты есть и `count() != secrets.count`,
  вызывает `updateSpotlight()`. Вызов после `refreshAll()` при запуске и в `poll()` каждые
  120 тиков (10 минут).
- Запуск с `--spotlight-check`, `--spotlight-clear` или `--snapshot` создаёт `Store.shared` в
  демо-режиме. Иначе такой запуск сам читает список и строит индекс, а проверка ничего не
  доказывает.
- `--spotlight-heal-check` для `tests/run.sh` не нужен: SC-001 проверяется живой проверкой
  агентом (очистить индекс флагом `--spotlight-clear`, подождать, `--spotlight-check`).

## Constitution Check

- I: значения не читаются, в индексе только имена и комментарии.
- III: только системные фреймворки.
- IV: живая проверка записывается в `tasks.md` с датой.
- V: команды `secret` не меняются.

## Complexity Tracking

Нет отступлений.
