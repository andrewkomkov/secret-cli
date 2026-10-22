# Implementation Plan: SecretBar — исправления после живой проверки

**Spec**: `specs/015-secretbar-live-fixes/spec.md`

## Technical Context

SwiftUI, macOS 26, `app/SecretBar`. Изменения только в приложении и в `tests/run.sh`.

- Раскладка: таблица соответствия клавиш ЙЦУКЕН и QWERTY (`Parse.swapLayout`). `Store.filter`
  ищет исходную строку, затем переведённую; дубликаты отбрасываются.
- Ссылки: `Parse.references` возвращает пары ключ → имя; `Store.envKeys` — ключ для имени.
- Карточка: выбор берётся из текущего списка, а не из всех секретов.
- Пустой список: `ContentUnavailableView` растягивается по высоте, поле поиска остаётся сверху.
- `--spotlight-check`: `CSSearchQuery` с `kMDItemDisplayName == "*"` в индексе приложения.
- `--snapshot`: экраны «пустой раздел» и «300 секретов» на демо-данных.

## Constitution Check

- I: значения не читаются, индекс Spotlight по-прежнему только имена и комментарии.
- III: только системные фреймворки.
- IV: проверки в `--selftest` и `tests/run.sh`; живая проверка записывается в `tasks.md` с датой.
- V: команды `secret` не меняются.

## Complexity Tracking

Нет отступлений.
