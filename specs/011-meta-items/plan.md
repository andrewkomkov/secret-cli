<!-- ste: E1.1 — the spec-kit template sets this heading -->
# Implementation Plan: Metadata items without Touch ID

**Branch**: `011-meta-items` | **Date**: 2026-10-07 | **Spec**: [spec.md](spec.md)

## Summary <!-- slop: the spec-kit template sets this heading -->

The name, comment and expiry of a secret move to a metadata item without `.userPresence`. Only
the agent reads the item with the value. `bin/secret` checks the helper with the command `ping`.
The test build writes each access to an item with a value to a log, and the tests check it.

## Constitution Check

| Principle | How it is met |
|---|---|
| I | values without changes |
| II | one Touch ID window per grace, attributes without Touch ID |
| IV | the access log in the test build replaces the windows, which the tests do not have |
| V | `secret __reindex` converts the store of 009 once |
