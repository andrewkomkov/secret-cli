# Research: data protection keychain store

<!-- ste: E8.7 — macOS and Xcode version numbers -->
Probes on 2026-10-07 on macOS 27.0, Xcode 27.0. A probe is a small `.app` (`spike/`), items with
service `secret-cli-dp-probe`. After each probe we deleted its items.

| # | Check | Result |
|---|---|---|
| R1 | `SecItemAdd` with `kSecUseDataProtectionKeychain`, a binary with an ad-hoc signature | `-34018` (`errSecMissingEntitlement`) |
| R2 | The same, `.app` with an Apple Development signature of a free Personal Team and `keychain-access-groups` | `0`, read `0` |
| R3 | Profile validity of a Personal Team for macOS | 7 days (`CreationDate` 2026-10-07, `ExpirationDate` 2026-10-14) |
| R4 | `keychain-access-groups` in the profile | `TEAM.*`: any binary of the team gets any group of the team. Any process of the user can sign a binary without questions (`xcodebuild` signed the probe without a window) |
| R5 | Item with `SecAccessControl(.userPresence)`; read with `LAContext.interactionNotAllowed` | write `0`; read without a window `-25308`, no window |
| R6 | Attributes (`kSecReturnAttributes`) of an item with `.userPresence` without a context | in the probe, read without a window. Not true for the working store: the keychain asks for Touch ID (011 R12) |
| R7 | `SecItemUpdate` of attributes or the value without Touch ID | `-25308`: a change requires Touch ID |
| R8 | `SecItemDelete` without Touch ID | `0`: deletion without Touch ID |
| R9 | `LAContext` after `evaluatePolicy`: reads after 10 s, 120 s, 290 s, `interactionNotAllowed` after the confirmation | one Touch ID question; reads after 10 s, 120 s and 290 s — `0` |
| R10 | One `LAContext` for two reads in a row | one Touch ID window |

## Decisions

**Store.** Data protection keychain, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` and
`.userPresence` on each value. Rationale: R4 — the signature does not separate our helper from any
binary that the agent signs. Only the Touch ID check in the system itself gives protection (R5).

Alternatives: items without `.userPresence` and Touch ID in the helper, as in 007. This decision
is rejected. Reason: the agent builds its own binary with the same group and reads the value. It
does not need Touch ID.

**Grace.** The agent process of the helper holds a confirmed `LAContext` (R9) and answers through
the unix socket `~/.local/state/secret/agent.sock` (directory 0700). The context cannot be passed
to another process, so the agent itself asks for the first Touch ID. Alternatives:

- the mark file with an authentication code (HMAC) from 007 does not work. The value requires the
  system Touch ID. The mark does not replace it.
- no grace: a question on each `secret run`.

**Write.** New value: delete the old item and add a new one (R8, without Touch ID), as
`security add-generic-password -U` did before. Comment and expiry date: `SecItemUpdate` through the
agent with a confirmed context (R7).

**Store selection.** A mode file, not an item in the store. If the profile has expired and the
helper does not start, the command must report an error. A silent fallback to the file keychain is
not allowed.

**Build.** `xcodebuild -allowProvisioningUpdates` with `DEVELOPMENT_TEAM`. The Team ID is the
`OU` field of the `Apple Development` certificate in the login keychain. Bundle ID
`secretcli.<team>.store`: it is unique at Apple without a personal name in the repo.
`CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO`: without `get-task-allow`, a debugger cannot attach to the
helper. Hardened runtime is on.

**Renewal.** `install.sh --renew` deletes the local profile of this bundle ID and rebuilds the
helper when less than 3 days remain until expiry. A LaunchAgent runs this once a day. The check
that a new profile gets a new expiry date is manual, on 2026-10-11 or later (a T task in `tasks.md`).
