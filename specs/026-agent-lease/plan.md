<!-- ste: E1.1 — heading set by the spec-kit template -->
# Implementation Plan: Secret lease for agents

**Branch**: `026-agent-lease` | **Date**: 2026-11-03 | **Spec**: [spec.md](spec.md)

## Summary <!-- slop: heading set by the spec-kit template -->

The lease is held by the same helper agent process `secret-vault` that holds grace. The agent
gets a new request `lease`: a new Touch ID, a read of the named values, a record in the lease
table with the end of the term. A screen lock and a Mac sleep now end only grace: the agent
closes the context and clears the grace cache. If a lease exists, the agent continues to work.
If there is no lease, the agent exits, as before.

While the screen is locked, the agent answers a read only from the lease table; for other names
it gives the error `not leased`. `bin/secret` gets the command
`lease`, the mark `lease` in the log and a status line for SecretBar.

## Technical Context

**Language and version**: Swift 6.4 in Swift 5 mode, bash 3.2, SwiftUI for SecretBar.

**Primary Dependencies**: the same as in 010: Foundation, CoreGraphics, LocalAuthentication.

**Storage**: the lease lives only in the agent memory. It does not go to disk: a restart and a
logout end the process and the lease.

**Testing**: `tests/run.sh` on the test build. The lease limit is `SECRET_TEST_MAX_LEASE`.
Screen lock is `test-lock`: in the test build it sets the state "screen locked" in the agent.
`test-unlock` clears it. Sleep is `test-sleep`.

**Constraints**: the lease term is counted by `CLOCK_MONOTONIC` (it runs during sleep). The
24-hour limit is hard-coded in the release build.

## Constitution Check

| Principle | How it is met |
|---|---|
| I | lease values only in the agent memory, output as in `read`; `lease status` gives only names |
| II | each lease is a new Touch ID with the names and the term in the window; limit 24 hours; `lock` ends the lease. A lock and a sleep keep the lease — **change of principle II** (2.4.0) |
| III | no new dependencies |
| IV | test build: `test-lock`, `test-unlock`, `test-sleep`, `SECRET_TEST_MAX_LEASE` |
| V | new command `lease`; `read`, `lock`, `touchid status` and grace unchanged for the owner |

Gate: the change of II is allowed only as a separate constitution commit before the code
(Governance).

## Project Structure

```text
.specify/memory/constitution.md   # II: lease rule, version 2.4.0
helper/store/main.swift           # agent: lease table, requests lease / lease-status / revoke,
                                  # lock and sleep end only grace
bin/secret                        # cmd_lease, lease log, help
hooks/claude-pretooluse.sh        # check: lease is not stopped (no rule needed, a test is needed)
app/SecretBar/                    # lease line and revoke button, ru in Localizable.xcstrings
docs/claude-md-secrets.md         # rule for the agent
README.md, README.ru.md, site/    # description of the command
tests/run.sh                      # SC-001..SC-004
```

Details: [research.md](research.md), [contracts/cli.md](contracts/cli.md),
[data-model.md](data-model.md), [quickstart.md](quickstart.md).

## Complexity Tracking

| Deviation | Reason |
|---|---|
| A screen lock and a sleep keep the lease (II) | the owner decided so on 2026-11-03: agents work without the owner. Limits: explicit list, Touch ID for each lease, 24 hours, `lock` |
| A term of up to 24 hours while the grace limit is 8 hours (II) | owner's decision: night work of the agent |
| The agent lives after a screen lock if a lease exists | before, the agent exited; now it exits only when there is no lease |
