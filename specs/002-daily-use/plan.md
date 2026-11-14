# Implementation Plan: Daily convenience

**Branch**: `002-daily-use` | **Date**: 2026-10-02 | **Spec**: [spec.md](spec.md)

## Summary <!-- slop: the heading comes from the spec-kit template -->

- `copy`: `pbcopy` of the value, a background `( sleep N; compare the sha256 of the clipboard; clear )`.
  For tests, `pbcopy`/`pbpaste` are replaced by the variables `SECRET_PBCOPY`/`SECRET_PBPASTE`, but
  only with a `SECRET_KEYCHAIN` that is not the default keychain.
- Name cache: the function `refresh_names` writes the output of `ls` to a file after changes.
- `mv`: read the value, comment and expiry, write NEW, delete OLD.
- Expiry: `write_item` always passes `-G` (the `gena` attribute). The value comes from the item if
  it is not changed. Dates go through `date -j -f %Y-%m-%d`.
- `completions/_secret`: commands, names from the cache, after `--` in `run` — normal command completion.

## Constitution Check

| Principle | How it is met |
|---|---|
| I | `copy` puts the value into the clipboard and does not print it; the background process keeps only a hash |
| III | `pbcopy`, `pbpaste`, `shasum`, `date` — from macOS |
| IV | tests use a replaced clipboard and a temporary name cache |
| V | `set` without `-x` keeps the expiry of the item, `ls` without flags prints the same as before |

## Complexity Tracking

No deviations.
