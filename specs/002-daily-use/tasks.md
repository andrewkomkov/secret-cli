# Tasks: Daily convenience

**Input**: `specs/002-daily-use/` (spec.md, plan.md)

## Phase 1: Foundation

- [x] T001 `write_item` with the `gena` attribute, reading `gena` and `icmt` with one function
- [x] T002 Name cache `refresh_names` after `ls`, `set`, `gen`, `rm`; variable `SECRET_NAMES_CACHE`

## Phase 2: User Story 1 — copy (P1)

- [x] T003 [US1] `secret copy NAME [SECONDS]`, clipboard clearing, log entry
- [x] T004 [US1] Tests on a replaced clipboard: value in the clipboard, clearing, other text stays, no value in the output

## Phase 3: User Story 3 — mv (P2)

- [x] T005 [US3] `secret mv [-f] OLD NEW`
- [x] T006 [US3] Tests: value, comment and expiry moved, OLD is gone, refusal without `-f`

## Phase 4: User Story 4 — expiry (P2)

- [x] T007 [US4] `set -x DATE`, `secret expire NAME DATE|none`, date check
- [x] T008 [US4] `ls --expiring [DAYS]`, date in `ls -l`, warning in `run` and `check`
- [x] T009 [US4] Tests: save, remove, wrong date, `--expiring`, warning

## Phase 5: User Story 2 — completion (P2)

- [x] T010 [US2] `completions/_secret`
- [x] T011 [US2] `install.sh` puts `_secret` into `$ZSH_CUSTOM/completions`
- [ ] T012 [US2] Check: `zsh -n`, and Tab in the owner's terminal (manual check) **`zsh -n` and loading `_secret` in zsh checked on 2026-10-02, Tab waits for the owner**

## Phase 6: Documents

- [x] T013 README, `secret help`, `docs/claude-md-secrets.md`, the Secrets section in `~/.claude/CLAUDE.md`
