# Implementation Plan: Leak protection during agent work

**Branch**: `001-agent-safety` | **Date**: 2026-10-02 | **Spec**: [spec.md](spec.md)

## Summary <!-- slop: the heading comes from the spec-kit template -->

Four additions to `bin/secret` and one new hook file.

- `gen`: 512-byte chunks from `/dev/urandom` through `tr -dc` up to the needed length, written with
  `cmd_set` (the value goes to the stdin of `security -i`).
- `run --mask`: the command runs without `exec`. stdout goes to a masker through a pipe, stderr
  goes through a FIFO to a second masker. The masker is `perl`. It gets the values in an
  environment variable of its own process only and replaces them from longest to shortest. The exit code comes from
  `PIPESTATUS[0]`, then the script waits for the stderr masker.
- Log: the function `audit` writes a TSV line, `secret log` is `tail` and a filter by name.
- Hook: `perl` with `JSON::PP` (it is in the system perl) gets `tool_input.command`, checks the
  patterns, on a match — code 2 and the reason in stderr.

## Technical Context

**Language and version**: bash 3.2, perl 5 (system)

**Testing**: `tests/run.sh`; for the hook — JSON on stdin and the exit code

**Constraints**: constitution, principles I, III, IV

## Constitution Check

| Principle | How it is met |
|---|---|
| I | `gen` and `log` print no values; the masker gets the values not through `argv` |
| II | `gen` does not replace human input: it creates a new value that nobody knows |
| III | only `bash`, `perl`, `tr`, `mkfifo` |
| IV | all checks are in `tests/run.sh`; in tests the log goes to a temporary file |
| V | `run` without `--mask` works as before (`exec`) |

## Complexity Tracking

| Deviation | Reason |
|---|---|
| `install.sh --claude-hook` edits `settings.json` with `/usr/bin/python3` (principle III) | `JSON::PP` in perl does not keep the key order: the owner's file would be rewritten in full. `python3` is in Command Line Tools and is needed only to install the hook; the `secret` command itself does not use it |
