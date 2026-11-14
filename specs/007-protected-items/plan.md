# Implementation Plan: Items that only the helper reads

**Branch**: `007-protected-items` | **Date**: 2026-10-02 | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

## Summary <!-- slop: the heading comes from the spec-kit template -->

In protected mode, the helper is the only reader of values. The mode is set by the existence of the item
`__secret-cli.policy`. In protected mode, `bin/secret` calls `secret-auth read/write/delete`,
in normal mode it calls `security`, as now.

Helper (Swift, legacy Keychain API): search with `SecKeychainFindGenericPassword`, creation with
`SecKeychainAddGenericPassword`, attributes with `SecKeychainItemModifyAttributesAndData`, deletion with
`SecKeychainItemDelete`. The check "the item is mine": a read of the data with the UI off succeeds only for
the creator.

Touch ID: `LAContext.evaluatePolicy(.deviceOwnerAuthentication)`. Grace: a file with the time and
HMAC-SHA256 (`CryptoKit`) with the key from the policy. If there is no policy or it cannot be read, grace is 0.

Migration (`touchid on`, helper update): the values go through a pipe between processes and are not written
to disk. The order for each item: create `NAME#new` → check the read → delete the old one →
rename `NAME#new` to `NAME` (the `svce` attribute).

## Technical Context

**Language and version**: Swift 5 mode, bash 3.2

**Primary Dependencies**: Security (legacy API, deprecated), LocalAuthentication, CryptoKit

**Testing**: a test build of the helper `-D SECRET_TEST` in a temporary directory; a second test
build with other code — for the migration and for the refusal to a foreign binary

## Constitution Check

| Principle | How it is met |
|---|---|
| I | values between the helper and bash go through a pipe; during migration they are not written to disk |
| II | Touch ID is inside the helper; turning off needs Touch ID |
| III | the helper is built from source in the repo, `swiftc` and `codesign` from Command Line Tools |
| IV | a test build of the helper on a temporary keychain; real Touch ID and the `security` dialog are a manual check |
| V | `touchid off` and the mode without the helper work as before |

## Complexity Tracking

| Deviation | Reason |
|---|---|
| `touchid on` changes how all items are stored (principle V) | otherwise a call to `security` goes around Touch ID |
| The test helper differs from the production one (`-D SECRET_TEST`) | Touch ID cannot be pressed in a test, and a Touch ID bypass must not get into the production binary |
