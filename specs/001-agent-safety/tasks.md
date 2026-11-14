# Tasks: Leak protection during agent work

**Input**: `specs/001-agent-safety/` (spec.md, plan.md)

## Phase 1: User Story 1 — gen (P1)

- [x] T001 [US1] `secret gen` with `-l`, `-s alnum|symbols|hex`, `-c`, `-f`
- [x] T002 [US1] Tests: length, character set for the three sets, refusal without `-f`, replacement with `-f`, no value in the output

## Phase 2: User Story 2 — run --mask (P1)

- [x] T003 [US2] `secret run --mask` and `SECRET_RUN_MASK=1`: stdout and stderr through the masker, exit code of the command
- [x] T004 [US2] Tests: `***` in stdout and stderr, exit code 7, a value inside another value, plain `.env` values are not masked

## Phase 3: User Story 3 — log (P2)

- [x] T005 [US3] Function `audit` in `get` and `run`, `SECRET_LOG`, mode 600
- [x] T006 [US3] `secret log [-n N] [NAME]`
- [x] T007 [US3] Tests: lines after `get` and `run`, the `agent`/`human` field, no values in the file, `SECRET_LOG=off`

## Phase 4: User Story 4 — Claude Code hook (P2)

- [x] T008 [US4] `hooks/claude-pretooluse.sh`: 8 patterns from spec.md, code 2 and the reason
- [x] T009 [US4] Hook tests: 8 blocks and 5 passes (SC-002) **2026-10-02**: 12 blocks and 8 passes. At first the hook blocked words in text (heredoc, commit messages). Now the rules look at the start of the command, and there are tests for this
- [x] T010 [US4] `install.sh --claude-hook`: add the hook to `~/.claude/settings.json` without touching the other settings
- [x] T011 [US4] Install the hook for the owner and check from Claude Code: `secret get` is blocked (manual check) **2026-10-02**: the hook is in `~/.claude/settings.json`, the command from Claude Code was stopped with a reason

## Phase 5: Documents

- [x] T012 README, `secret help`, `docs/claude-md-secrets.md` and the Secrets section in `~/.claude/CLAUDE.md`
