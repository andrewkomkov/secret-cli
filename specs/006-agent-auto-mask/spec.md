# Feature Specification: Masking for the agent by default

**Feature Branch**: `006-agent-auto-mask` (the work is done in `main` of the local repo)

**Created**: 2026-10-02

**Status**: Done — 2026-10-02

**Input**: Now `--mask` rests on a rule in `CLAUDE.md`: if the agent does not write the flag,
the value goes to the output. Also, masking does not catch an encoded value.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The agent cannot forget `--mask` (Priority: P1)

**Acceptance Scenarios**:

1. **Given** `CLAUDECODE=1`, **When** `secret run NAME -- cmd` without `--mask`, **Then** the output is masked.
2. **Given** `CLAUDECODE=1`, **When** `secret run --no-mask ...`, **Then** masking stays, a warning goes to stderr.
3. **Given** a human without `CLAUDECODE`, **When** `--no-mask` or no flag, **Then** the output is not masked, as before.
4. **Given** `CLAUDECODE=1`, **When** cmd prints the whole environment (`python3 -c 'print(os.environ)'`), **Then** the secret values in the output are `***`.

### User Story 2 - Encoded value (Priority: P2)

**Acceptance Scenarios**:

1. **When** cmd prints the value in base64 or URL-encoded, **Then** `***` is in its place.

### Edge Cases

- A value shorter than 8 characters: the base64 and URL variants are not masked, so that random pieces of text are not replaced. The value itself is masked.
- The URL variant is the same as the value (no characters to encode): one replacement.

## Requirements *(mandatory)*

- **FR-001**: `CLAUDECODE` is not empty → `run` always masks; `--no-mask` in this case gives a warning.
- **FR-002**: `--no-mask` for a human turns off `SECRET_RUN_MASK=1`.
- **FR-003**: The masker replaces the value, its base64 (standard and URL-safe, with and without `=`) and its URL encoding.

## Success Criteria *(mandatory)*

- **SC-001**: Test: under `CLAUDECODE=1`, the environment printed through `python3`/`env` has no values.
- **SC-002**: `tests/run.sh` passes in full.

## Assumptions

- `base64(user:pass)` in `Authorization: Basic` is not caught: it holds a different value. This is written in the README.
- The agent can run a command without `CLAUDECODE` (`env -u CLAUDECODE`). The feature protects against a mistake, not against intent.
