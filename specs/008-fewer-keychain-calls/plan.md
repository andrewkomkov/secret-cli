# Implementation Plan: Fewer keychain calls

**Branch**: `008-fewer-keychain-calls` | **Date**: 2026-10-02 | **Spec**: [spec.md](spec.md)

## Summary <!-- slop: the heading comes from the spec-kit template -->

The variable `ITEMS` keeps the output of `list_items` (TSV: name, comment, expiry). The first
call of `items_cached` fills it, and each write and deletion clears it. `item_known`, `get_comment`,
`get_expiry` read from it with `awk`. The variable `BATCH=1` puts off `refresh_names` until
the end of a batch command. In `set`, the check after a write is a direct `security find-generic-password`.

## Constitution Check

| Principle | How it is met |
|---|---|
| I | the cache has only attributes, no values |
| V | the command output does not change |

## Complexity Tracking

No deviations.
