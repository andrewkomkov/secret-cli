<!-- ste: E1.1 — the spec-kit template sets this heading -->
# Implementation Plan: SecretBar menu bar app

**Branch**: `012-menu-bar-app` | **Date**: 2026-10-07 | **Spec**: [spec.md](spec.md)

## Summary <!-- slop: the spec-kit template sets this heading -->

SwiftUI `MenuBarExtra` with the window style. The model calls `secret` and the helper through
`Process` and parses the output. The app polls the grace state once in 5 seconds with the command
`grace-status`: it does not start the agent. The build is `xcodebuild`, ad-hoc signature.

## Technical Context

**Language and version**: Swift 6.4 in Swift 5 mode, SwiftUI, macOS 14.

**Primary Dependencies**: SwiftUI, AppKit (`NSPasteboard` is not necessary: `secret copy` handles
the clipboard), ServiceManagement (`SMAppService` for launch at login).

**Testing**: `SecretBar --selftest` in `tests/run.sh`. Binary check: no `SecItem*`, no
entitlements.

## Constitution Check

| Principle | How it is met |
|---|---|
| I | values only through stdin of `secret set` and `secret copy` |
| II | the helper agent asks for Touch ID, as for a command |
| III | exception 1.4.0: Xcode, ad-hoc signature |
| IV | `--selftest`, binary check; the interface is a manual check |
| V | `secret` commands without changes |

## Project Structure

```text
app/
├── SecretBar.xcodeproj/project.pbxproj
├── SecretBar/SecretBarApp.swift    # MenuBarExtra, icon
├── SecretBar/Model.swift           # secret calls, parsing, selftest
├── SecretBar/Views.swift           # tabs, rows, forms
└── build.sh                        # xcodebuild, ad-hoc signature
```
