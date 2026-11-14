# Implementation Plan: Touch ID

**Branch**: `004-touch-id` | **Date**: 2026-10-02 | **Spec**: [spec.md](spec.md)

## Summary <!-- slop: the heading comes from the spec-kit template -->

A helper in Swift with two commands: `auth` and `status`. `bin/secret` finds it in `build/` next to
itself (through the symlink). `require_auth` is called in `get`, `copy`, `run` (after the references are read, before
the command starts) and `export`. The reason in the dialog is the operation and the secret names. Test replacements
are allowed only if the inode of the keychain (`stat -L -f %d:%i`) differs from the default keychain.

## Technical Context

**Language and version**: Swift 5 mode (`swiftc -swift-version 5`), bash 3.2

**Primary Dependencies**: LocalAuthentication, Security (`SecKeychainGetStatus` is deprecated, but works in macOS 27)

## Constitution Check

| Principle | How it is met |
|---|---|
| II | a human gives the confirmation; turning it off also needs a confirmation |
| III | the helper is source code in the repo, built with `swiftc` from Command Line Tools |
| IV | a helper stub in tests; real Touch ID is a manual check |
| V | the default is `touchid off`, the commands work as before |

## Complexity Tracking

| Deviation | Reason |
|---|---|
| With `touchid on` and no helper, the command does not work (principle III says that without the helper the command works without its features) | otherwise deleting `build/secret-auth` would turn off Touch ID without a confirmation. With `touchid off`, the command works without the helper |
