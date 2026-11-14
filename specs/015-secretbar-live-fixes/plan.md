# Implementation Plan: SecretBar — fixes after the live check

**Spec**: `specs/015-secretbar-live-fixes/spec.md`

## Technical Context

SwiftUI, macOS 26, `app/SecretBar`. Changes only in the app and in `tests/run.sh`.

- Layout: a key map between Russian JCUKEN and QWERTY (`Parse.swapLayout`). `Store.filter`
  searches for the source string, then for the converted one; duplicates are dropped.
- References: `Parse.references` returns key → name pairs; `Store.envKeys` gives the key for a name.
- Card: the selection comes from the current list, not from all secrets.
- Empty list: `ContentUnavailableView` stretches in height, the search field stays at the top.
- `--spotlight-check`: `CSSearchQuery` with `kMDItemDisplayName == "*"` in the index of the app.
- `--snapshot`: the screens "empty section" and "300 secrets" on demo data.

## Constitution Check

- I: values are not read, the Spotlight index still holds only names and comments.
- III: only system frameworks.
- IV: checks in `--selftest` and `tests/run.sh`; the live check is recorded in `tasks.md` with a date.
- V: the `secret` commands do not change.

## Complexity Tracking

No deviations.
