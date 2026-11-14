# Tasks: Touch ID

**Input**: `specs/004-touch-id/` (spec.md, plan.md)

- [x] T001 `helper/secret-auth.swift`: `auth` and `status`
- [x] T002 `install.sh`: build into `build/secret-auth`, `build/` in `.gitignore`
- [x] T003 [US2] `is_unlocked` through the helper
- [x] T004 [US1] Config, `secret touchid on|off|status|grace`, replacements only for a keychain with another inode
- [x] T005 [US1] `require_auth` in `get`, `copy`, `run`, `export`, timestamp and grace
- [x] T006 [US1] Hook: the rules of FR-007
- [x] T007 Tests with a helper stub (SC-001), replacements with the default keychain do not work, hook rules **2026-10-02**: a bug was found — without the helper, the check was skipped within grace; fixed
- [ ] T008 [US2] Tests on a locked keychain through the helper (SC-002, first run — manual check of the dialog) **2026-10-02**: the test passes; the owner has not yet confirmed that there was no dialog
- [ ] T009 [US1] Manual Touch ID check on the owner's Mac (SC-003)
- [x] T010 README, `secret help`, `docs/claude-md-secrets.md`, the Secrets section in `~/.claude/CLAUDE.md`
