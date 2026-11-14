# Implementation Plan: SecretBar в системном поиске Siri и Spotlight

**Spec**: `specs/035-secretbar-system-search/spec.md`

## Technical Context

- `app/SecretBar/Intents.swift`: `SearchSecretsIntent` (схема `.system.search`, `searchScopes`
  `[.general]`, `criteria: StringSearchCriteria`). `perform` зовёт `Navigation.shared.search`.
- `Intents.swift`: `extension SecretQuery: IndexedEntityQuery` под `#if compiler(>=6.4)` и
  `@available(macOS 27, *)`. Оба метода зовут `Store.shared.updateSpotlight()`: он сам смотрит на
  переключатель.
- `QuickPanel.swift`, `Navigation`: `searchPending: String?`, `search(_:)` открывает главное окно.
- `MainWindow.swift`: `takeSearchRequest()` на `onAppear` и `onChange(of: nav.searchPending)`
  ставит текст в `query`.
- `Localizable.xcstrings`: новые строки интерфейса получают `ru`.

## Constitution Check

- **I**: в индекс и поиск идут только имена и комментарии.
- **II–III**: SecretBar зовёт только `bin/secret` и helper. Новых прав и entitlements нет.
- **IV**: `tests/run.sh` проверяет сборку SecretBar, как раньше. Поиск через Siri — ручная проверка.
- **V**: новое действие. Старые действия и переключатель не меняются.

## Complexity Tracking

Нет отступлений.
