# Implementation Plan: Enter copies the reference, a new secret from the panel

**Spec**: `specs/025-enter-reference/spec.md`

## Technical Context

- `Store.pick(_ name:, value:)`: `copy` or `copyReference`. The ⇧ flag: `KeyPress.modifiers` in
  `onKeyPress(.return)`; in `onSubmit` and in a click, `NSEvent.modifierFlags`.
- Quick panel: `onKeyPress(.return)` on the field, `onSubmit` is the fallback path.
- Menu bar panel: the `plus` button in the header, `⌘N`, the row "Create NAME" when the result is empty.
- Main window: `onKeyPress(.return)` of the list looks at ⇧.
- `Navigation.newSecret(name:)` puts the name into `addName`; `EditorSheet` takes it when it appears.

## Constitution Check

- I: the reference is a name, not a value. Only the helper still puts the value into the clipboard.
- II: ⇧↩ asks for Touch ID, as ↩ did before.
- IV: `--selftest` checks the choice of the action and the name from the query.
- V: the change of the ↩ key is a deviation, see below.

## Complexity Tracking

| Deviation | Reason |
|---|---|
| ↩ copies the reference instead of the value | Request of the owner. The value is ⇧↩ |
