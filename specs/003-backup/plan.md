# Implementation Plan: Encrypted backup

**Branch**: `003-backup` | **Date**: 2026-10-02 | **Spec**: [spec.md](spec.md)

## Summary <!-- slop: the heading comes from the spec-kit template -->

`export` collects the lines in a bash variable (in memory) and gives them to `openssl` through a pipe. The password
goes to `-pass fd:3` from the process substitution `3< <(printf ...)`: this is a pipe, not a temporary file
as with a here-string in bash 3.2. `restore` decrypts into a variable, checks the header and
sha256, and only then writes the items with `write_item`.

## Constitution Check

| Principle | How it is met |
|---|---|
| I | values only inside the encrypted file; the password is not in `argv` and not in the environment |
| II | a human types the backup password (terminal or dialog); `--pass-stdin` is an explicit flag |
| III | `openssl` (LibreSSL), `xxd`, `shasum` from macOS |
| IV | a test on two temporary keychains |
| V | new commands, the old ones do not change |

## Complexity Tracking

No deviations.
