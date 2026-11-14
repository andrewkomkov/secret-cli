# Tasks: Encrypted backup

**Input**: `specs/003-backup/` (spec.md, plan.md)

- [x] T001 [US1] `secret export [-f] [--pass-stdin] FILE`: collect the items, encrypt, mode 600, log entry
- [x] T002 [US2] `secret restore [-f] [--pass-stdin] FILE`: decrypt, check the header and sha256, write, skip the existing ones
- [x] T003 Tests: export → restore into another keychain (SC-001), no plain text in the file (SC-002), wrong password, damaged file, `-f`, short password, refusal to overwrite the file **2026-10-02**: 20 checks. A bug was found: an empty comment moved the expiry into the comment field; an empty field is now `-`
- [ ] T004 Manual check: export with the password in a macOS dialog
- [x] T005 README, `secret help`, `docs/claude-md-secrets.md`, the Secrets section in `~/.claude/CLAUDE.md`
