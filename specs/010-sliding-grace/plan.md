<!-- ste: E1.1 — the spec-kit template sets this heading -->
# Implementation Plan: Sliding grace

**Branch**: `010-sliding-grace` | **Date**: 2026-10-07 | **Spec**: [spec.md](spec.md)

## Summary <!-- slop: the spec-kit template sets this heading -->

The agent of the helper `SecretStore` extends grace after each request: the end of grace is now
plus the idle time. The limit is 8 hours from Touch ID. The agent sees a screen lock from a
notification and from a poll of the session state. The agent sees Mac sleep from the difference
between the clock that counts sleep and the clock that does not. Then the agent closes the
context and stops. The client repeats the request if the agent closed the connection without an
answer. The agent loop moves from `poll` to the `RunLoop` of the main thread: notifications need
a `RunLoop`.

## Technical Context

**Language and version**: Swift 6.4 in Swift 5 mode, bash 3.2.

**Primary Dependencies**: Foundation (`DistributedNotificationCenter`), CoreGraphics
(`CGSessionCopyCurrentDictionary`), LocalAuthentication.

**Storage**: the policy `__secret-cli.policy`, format `v1 grace=N` without changes.

**Testing**: `tests/run.sh` on the test build. The limit is the variable `SECRET_TEST_MAX_GRACE`.
The lock signal is the command `test-lock` of the test build; it sends its own notification.

**Constraints**: a monotonic clock for the limit (`CLOCK_MONOTONIC`, it also runs during Mac
sleep).

## Constitution Check

| Principle | How it is met |
|---|---|
| I | no changes |
| II | idle time ≤ 3600, limit 8 hours, screen lock, sleep and `lock` end grace (1.2.0) |
| III | CoreGraphics is part of macOS |
| IV | test build; `test-lock` and `SECRET_TEST_MAX_GRACE` are only in it |
| V | `touchid grace N` and the policy format stay the same; N is now the idle time (deviation) |

## Project Structure

```text
helper/store/main.swift   # agent: RunLoop, sliding end of grace, notifications, status
bin/secret                # touchid status: idle time, limit, grace remaining
tests/run.sh              # SC-001..SC-003
```

## Complexity Tracking

| Deviation | Reason |
|---|---|
| `touchid grace N` sets the idle time, not the time from Touch ID (V) | the owner asked for this; screen lock and sleep restrict grace |
| Default 1800 instead of 300 | the owner chose 30 minutes of idle time |
