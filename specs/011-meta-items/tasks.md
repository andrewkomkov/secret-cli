# Tasks: Metadata items without Touch ID

**Input**: `specs/011-meta-items/` (spec.md, plan.md, research.md)

- [x] T001 `helper/store/main.swift`: metadata items `secret-cli.meta`. `list`, `has`, `attrs`, `policy show` and the change check in the agent work with them
- [x] T002 `helper/store/main.swift`: `ping`, `reindex`, the agent log, the access log of the test build `SECRET_TEST_VALUE_LOG`
- [x] T003 `bin/secret`: the check through `ping`, the command `__reindex`
- [x] T004 `tests/run.sh`: only the agent accesses the items with values. `note` and `expire` work without Touch ID. 278 checks, 2026-10-07
- [x] T005 Return of the sliding grace from 010, based on metadata items
- [x] T006 Constitution 1.3.0, corrections in research 009 R6 and 010 R11
- [x] T007 `README.md`, `docs/claude-md-secrets.md`, the Secrets section in `~/.claude/CLAUDE.md`
- [x] T008 Manual check of SC-002, 2026-10-07. `__reindex` created 50 metadata items, 1 window. `ls`, `ls -l`, `has`, `touchid status`: 0 windows. Two `run`: 1 window (R14)
