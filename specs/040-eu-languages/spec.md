# Feature Specification: European languages

**Feature Branch**: `040-eu-languages`

**Created**: 2026-11-14

**Status**: Done 2026-11-14

**Input**: Owner, 2026-11-14: "make the software multilingual, add 5-6 European languages".

## Goal

SecretBar, the Safari extension and the landing speak German, French, Spanish, Italian,
Portuguese and Polish, in addition to English and Russian.

| Code | Language |
|---|---|
| `de` | German |
| `fr` | French |
| `es` | Spanish |
| `it` | Italian |
| `pt-PT` | Portuguese (Portugal) |
| `pl` | Polish |

## Scope

- `app/SecretBar/Localizable.xcstrings`: each string gets the six languages.
- `knownRegions` in `app/SecretBar.xcodeproj/project.pbxproj`.
- App Shortcuts phrases in `Intents.swift`: phrases for each language.
- `app/extension/_locales/<lang>/messages.json` for the six languages.
- The landing of feature 038 in the same languages.

## Out of scope

- The messages of the command `secret`. A command line tool stays in English. Scripts and agents
  parse its output.

## Requirements

- **FR-001**: a string with a format (`%@`, `%lld`) keeps the same format arguments in each
  language.
- **FR-002**: the product names stay in English: SecretBar, Touch ID, Secure Enclave, Keychain,
  Safari, Claude Code.
- **FR-003**: a new interface string gets all eight languages in the same change (update of the
  rule in `CLAUDE.md`).

## Success Criteria

- **SC-001**: a test in `tests/run.sh` checks that each key of the catalog and of the extension has
  each language. The test also checks the format arguments.
- **SC-002**: SecretBar builds. With the system language German, the menu is in German (manual
  check, date).
