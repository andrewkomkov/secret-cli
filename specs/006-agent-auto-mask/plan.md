# Implementation Plan: Masking for the agent by default

**Branch**: `006-agent-auto-mask` | **Date**: 2026-10-02 | **Spec**: [spec.md](spec.md)

## Summary <!-- slop: the heading comes from the spec-kit template -->

In `cmd_run`, the flag `mask` is set to 1 when `CLAUDECODE` is not empty. `--no-mask` clears it only
without `CLAUDECODE`. In `MASK_PL`, each value of 8 characters or more gets variants:
`MIME::Base64::encode_base64` (with and without `=`), URL-safe base64 and URL encoding `%XX`. The modules are
from the perl core.

## Constitution Check

| Principle | How it is met |
|---|---|
| I | fewer paths by which a value gets into the output |
| V | for a human, the behavior of `run` is the same; the agent always gets masking — this is a change of behavior, see below |

## Complexity Tracking

| Deviation | Reason |
|---|---|
| `run` under `CLAUDECODE` changes behavior: the output is masked without the flag (principle V) | without this, masking rests on the agent's memory; the owner asked to remove this dependency |
