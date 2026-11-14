<!-- ste: E1.1 — heading set by the spec-kit template -->
# Implementation Plan: Data protection keychain store

**Branch**: `009-data-protection-store` | **Date**: 2026-10-07 | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

## Summary <!-- slop: heading set by the spec-kit template -->

The new helper `SecretStore.app` works with the data protection keychain through `SecItem*`.
The values are protected by `.userPresence`: the system checks Touch ID (research R4, R5).
`bin/secret` selects the store by the mode file. In mode `dp`, all operations go through the helper.

The agent process
of the helper holds grace with a confirmed `LAContext`. The move: `secret migrate --backup FILE`
and `secret migrate --back`. The Personal Team profile is valid for 7 days. `install.sh --renew`
and a LaunchAgent renew it.

## Technical Context

<!-- ste: E8.7, E8.3 — label set by the spec-kit template, version numbers -->
**Language/Version**: Swift 6.4 in Swift 5 mode, bash 3.2

**Primary Dependencies**: Security (`SecItem*`, `SecAccessControl`), LocalAuthentication,
Foundation. Xcode 27 (`xcodebuild`), an Apple Development certificate of a free Personal Team.

**Storage**: data protection keychain. Mode file `~/.local/state/secret/store`.

**Testing**: `tests/run.sh`. The test build of the helper (configuration `Test`, `SECRET_TEST`) in
`build/test/`. If Xcode or a Personal Team is not present, the tests are skipped with a message.

**Target Platform**: macOS 14+ on Apple silicon and Intel with Touch ID or the Mac password

<!-- ste: E1.9 — CLI is the usual project type name in the spec-kit template -->
**Project Type**: CLI (bash) and helper (`.app`)

<!-- ste: E8.7 — decimal numbers -->
**Performance Goals**: `ls`, `has`, `check` on 300 items: not slower than the file mode
(008: `check` 0.62 s). A read in grace: less than 0.2 s.

**Constraints**: values only through stdin and stdout (principle I). No paid account (III).

<!-- ste: E8.3 — label set by the spec-kit template -->
**Scale/Scope**: hundreds of items, one user, one Mac

## Constitution Check

| Principle | How it is met |
|---|---|
| I | values: bash ↔ helper — stdin/stdout in hex; helper ↔ agent — unix socket 0600 in a directory 0700 |
| II | `.userPresence` on each value, the system asks for Touch ID; grace ≤ 3600; `SECRET_NO_DIALOG=1` — an error without a window |
| III | exception from 1.1.0: `.app`, `xcodebuild`, Personal Team; without Xcode — the file keychain as before |
| IV | test build: its own bundle ID and access group, an account per run, deletion at the end; without Xcode the store tests are skipped with a message |
| V | all commands and `secret:NAME` stay the same; `migrate` turns on the new store; the way back is `migrate --back` |

## Project Structure

### Documentation (this feature)

```text
specs/009-data-protection-store/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md, tasks.md
├── contracts/helper-cli.md   # SecretStore commands and the agent protocol
└── spike/                    # probes R1–R10
```

<!-- ste: E2.1 — heading set by the spec-kit template -->
### Source Code (repository root)

```text
helper/
├── secret-auth.swift                       # file keychain, no changes
└── store/
    ├── main.swift                          # new helper (Xcode: top-level code only in main.swift)
    ├── SecretStore.entitlements            # keychain-access-groups
    ├── SecretStore.xcodeproj/project.pbxproj  # Release and Test configurations
    └── build.sh                            # build for install.sh and tests/run.sh
bin/secret                                  # store selection, migrate, dp branches
install.sh                                  # build, --renew, --launchd
hooks/claude-pretooluse.sh                  # new variables and direct helper call
tests/run.sh                                # tests on the test build
build/SecretStore.app, build/SecretStore.expires, build/SecretStore.src-sha256
```

## Complexity Tracking

| Deviation | Reason |
|---|---|
| Build through Xcode and Personal Team (III) | without the entitlement the data protection keychain is not available (R1); the exception is written in constitution 1.1.0 |
| `touchid off` and `unlock` in mode `dp` behave differently (V) | the system sets the protection on each item; the store has no lock of its own |
| `note`, `expire` in mode `dp` ask for Touch ID (V) | the system asks for Touch ID to change an item (R7) |
| The agent process lives after the command | a Touch ID context cannot be passed between processes (R9) |
| The test build differs from the release build (`SECRET_TEST`) | Touch ID cannot be pressed in a test; test code does not go into Release |
