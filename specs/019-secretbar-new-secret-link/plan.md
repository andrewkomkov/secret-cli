# Implementation Plan: SecretBar — "New secret…" in the menu and a reference after create

**Spec**: `specs/019-secretbar-new-secret-link/spec.md`

## Technical Context

SwiftUI, `app/SecretBar`. Changes only in the app.

- `Navigation.newSecret()`: the counter `addRequests` and `showMain()`. The main window watches the
  counter and sets `sheet = .add` if no other sheet is open.
- `Views.swift`: the item "New secret…" in the "…" menu.
- `EditorSheet.save()`: after a successful `add` or `generate`, it calls
  `Store.copyReference(name, saved: true)`. The toast joins "saved" and "reference in the clipboard".

## Constitution Check

- I: the name goes into the clipboard, the app does not see the value.
- III: only system frameworks.
- IV: the windows and the clipboard are checked by hand, the record goes into `tasks.md` with a date; `tests/run.sh` passes.
- V: the `secret` commands and the reference format do not change.

## Complexity Tracking

No deviations.
