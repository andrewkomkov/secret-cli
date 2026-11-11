# Feature Specification: SecretBar в системном поиске Siri и Spotlight

**Feature Branch**: `035-secretbar-system-search`

**Created**: 2026-11-11

**Status**: Draft 2026-11-11

**Input**: Владелец: «что-то специфичное под macOS 27». SDK macOS 27 (Xcode 27.2), 2026-11-11:
`IndexedEntityQuery` — система просит приложение заново проиндексировать сущности. Схема
`.system.search` (`ShowInAppSearchResultsIntent`, macOS 15+) — Siri и Spotlight открывают поиск
внутри приложения.

## Цель

Человек говорит Siri или пишет в Spotlight «найди в SecretBar shop». SecretBar открывает главное
окно, в поле поиска стоит `shop`. На macOS 27 Spotlight сам просит SecretBar обновить индекс, когда
он нужен.

## Контекст и границы

- В индекс и в поиск идут только имена и комментарии. Значения туда не идут, как в 014.
- Переключатель «Show in Spotlight» решает, как раньше: выключен — индекса нет.
- SecretBar по-прежнему сверяет индекс каждые 10 минут (016). На macOS 27 к этому добавляется
  запрос системы.
- Схемы для паролей или секретов в App Intents нет. Поэтому SecretBar использует только общую
  схему поиска.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - поиск из Siri и Spotlight (Priority: P1)

1. **When** система выполняет `SearchSecretsIntent` с текстом `TERM`, **Then** SecretBar открывает
   главное окно, раздел «All», и в поле поиска стоит `TERM`.
2. Окно уже открыто — SecretBar ставит `TERM` в поле поиска этого окна.

### User Story 2 - переиндексация по запросу системы (Priority: P2)

1. **When** macOS 27 вызывает `reindexAllEntities` или `reindexEntities`, **Then** SecretBar
   строит индекс заново из списка секретов.
2. Переключатель выключен — SecretBar индекс не строит.

## Requirements

- **FR-001**: `SearchSecretsIntent: ShowInAppSearchResultsIntent` с `@AppIntent(schema: .system.search)`.
- **FR-002**: `Navigation.search(TERM)`: запрос для главного окна, как `newSecret` (019).
- **FR-003**: `SecretQuery: IndexedEntityQuery` только на macOS 27 (`@available`) и только при сборке
  SDK macOS 27 (`#if compiler(>=6.4)`). CI на `macos-15` и `macos-26` собирает SecretBar без неё.

## Success Criteria

- **SC-001**: `app/build.sh` проходит на Xcode 27 (локально) и на Xcode CI.
- **SC-002**: ручная проверка: Spotlight или Shortcuts, действие «Search in SecretBar», окно открыто
  с текстом в поиске. Дата — при выполнении.
