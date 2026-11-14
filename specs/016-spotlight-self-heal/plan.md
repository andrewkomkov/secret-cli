# Implementation Plan: SecretBar — the Spotlight index restores itself

**Spec**: `specs/016-spotlight-self-heal/spec.md`

## Technical Context

SwiftUI, macOS 26, `app/SecretBar`.

- `SpotlightIndex.count() async -> Int?`: `CSSearchQuery` with `kMDItemDisplayName == "*"` on
  the index of its own bundle. On an error it returns `nil`. `--spotlight-check`
  and `Store` use it.
- `Store.healSpotlight()`: if Spotlight is on, secrets exist and `count() != secrets.count`,
  it calls `updateSpotlight()`. The call comes after `refreshAll()` at launch and in `poll()` every
  120 ticks (10 minutes).
- A launch with `--spotlight-check`, `--spotlight-clear` or `--snapshot` creates `Store.shared` in
  demo mode. Otherwise such a launch reads the list and builds the index itself, and the check
  proves nothing.
- `tests/run.sh` does not need `--spotlight-heal-check`: SC-001 is checked by a live check
  by the agent (clear the index with the `--spotlight-clear` flag, wait, `--spotlight-check`).

## Constitution Check

- I: values are not read, the index holds only names and comments.
- III: only system frameworks.
- IV: the live check is recorded in `tasks.md` with a date.
- V: the `secret` commands do not change.

## Complexity Tracking

No deviations.
