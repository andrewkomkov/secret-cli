# Implementation Plan: SecretBar in the Siri and Spotlight system search

**Spec**: `specs/035-secretbar-system-search/spec.md`

## Technical Context

- `app/SecretBar/Intents.swift`: `SearchSecretsIntent` (schema `.system.search`, `searchScopes`
  `[.general]`, `criteria: StringSearchCriteria`). `perform` calls `Navigation.shared.search`.
- `Intents.swift`: `extension SecretQuery: IndexedEntityQuery` under `#if compiler(>=6.4)` and
  `@available(macOS 27, *)`. Both methods call `Store.shared.updateSpotlight()`: it checks the
  switch itself.
- `QuickPanel.swift`, `Navigation`: `searchPending: String?`, `search(_:)` opens the main window.
- `MainWindow.swift`: `takeSearchRequest()` on `onAppear` and `onChange(of: nav.searchPending)`
  puts the text into `query`.
- `Localizable.xcstrings`: new interface strings get `ru`.

## Constitution Check

- **I**: only names and comments go into the index and the search.
- **II–III**: SecretBar calls only `bin/secret` and the helper. No new permissions and
  entitlements.
- **IV**: `tests/run.sh` checks the SecretBar build, as before. The search through Siri is a
  manual check.
- **V**: a new action. The old actions and the switch do not change.

## Complexity Tracking

No deviations.
