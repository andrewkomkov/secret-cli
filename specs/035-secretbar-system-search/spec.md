# Feature Specification: SecretBar in the Siri and Spotlight system search

**Feature Branch**: `035-secretbar-system-search`

**Created**: 2026-11-11

**Status**: Draft 2026-11-11

**Input**: Owner: "something specific to macOS 27". macOS 27 SDK (Xcode 27.2), 2026-11-11:
`IndexedEntityQuery` — the system asks the app to index the entities again. The schema
`.system.search` (`ShowInAppSearchResultsIntent`, macOS 15+) — Siri and Spotlight open the
search inside the app.

## Goal

A person tells Siri or types in Spotlight "find shop in SecretBar". SecretBar opens the main
window, and the search field holds `shop`. On macOS 27, Spotlight itself asks SecretBar to update
the index when it is needed.

## Context and scope

- Only names and comments go into the index and the search. Values do not go there, as in 014.
- The switch "Show in Spotlight" decides, as before: off — no index.
- SecretBar still checks the index every 10 minutes (016). On macOS 27, the system request is
  added to this.
- App Intents has no schema for passwords or secrets. So SecretBar uses only the general search
  schema.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - search from Siri and Spotlight (Priority: P1)

1. **When** the system runs `SearchSecretsIntent` with the text `TERM`, **Then** SecretBar opens
   the main window, section "All", and the search field holds `TERM`.
2. The window is already open — SecretBar puts `TERM` into the search field of this window.

### User Story 2 - reindex on the system request (Priority: P2)

1. **When** macOS 27 calls `reindexAllEntities` or `reindexEntities`, **Then** SecretBar builds
   the index again from the list of secrets.
2. The switch is off — SecretBar does not build the index.

## Requirements

- **FR-001**: `SearchSecretsIntent: ShowInAppSearchResultsIntent` with `@AppIntent(schema: .system.search)`.
  The macro is in the SDK of Xcode 26+ (`#if compiler(>=6.2)`). The Xcode 16 build (CI
  `macos-15`) does not contain the action.
- **FR-002**: `Navigation.search(TERM)`: a request for the main window, as `newSecret` (019).
- **FR-003**: `SecretQuery: IndexedEntityQuery` only on macOS 27 (`@available`) and only in a
  build with the macOS 27 SDK (`#if compiler(>=6.4)`). CI on `macos-15` and `macos-26` builds
  SecretBar without it.

## Success Criteria

- **SC-001**: `app/build.sh` passes on Xcode 27 (locally) and on the CI Xcode.
- **SC-002**: manual check: Spotlight or Shortcuts, the action "Search in SecretBar", the window
  is open with the text in the search. Date — when done.
