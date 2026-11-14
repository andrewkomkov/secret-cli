# Tasks: a hook without false positives

**Input**: `specs/023-hook-precision/spec.md`

- [x] T001 [US1] `hooks/claude-pretooluse.sh`: the heredoc body for `cat`, `tee`, `git` is not checked
- [x] T002 [US2] `hooks/claude-pretooluse.sh`: store helper — list of read programs
- [x] T003 `tests/run.sh`: checks `023:`, the previous `hook blocks` pass
- [x] T004 `hooks/install-claude.sh`: the hook in `settings.json` and the line `@docs/claude-md-secrets.md` in `CLAUDE.md`. A repeated run and a new path replace the previous entries
- [x] T005 `CLAUDE.md` in the repository root, README, constitution 2.2.1
- [x] T006 2026-10-22, owner's Mac: `./install.sh --claude-hook --app`. `~/.claude/CLAUDE.md` has the rules import line. The hook let through a heredoc with the text `secret touchid repair` and `codesign --verify` of the store helper
- [x] T007 2026-10-22: tag `v1.1.0`, formula 1.1.0 in the tap. `brew install` from GitHub, `brew test` and `brew audit --strict` pass
