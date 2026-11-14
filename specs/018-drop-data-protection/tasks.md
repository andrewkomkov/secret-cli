# Tasks: remove the data protection store

**Input**: `specs/018-drop-data-protection/spec.md`

- [x] T001 [US1] `helper/store/main.swift`, `bin/secret`: `drop` and `migrate --drop-dp`
- [x] T002 [US1] 2026-10-14: `secret migrate --drop-dp` compared 68 names and after Touch ID deleted the data protection items (values, service items, policy)
- [x] T003 [US2] Constitution 2.0.0
- [x] T004 [US2] `helper/store/`: only Secure Enclave, `build.sh` on `swiftc`
- [x] T005 [US2] `bin/secret`, `completions/_secret`, `hooks/claude-pretooluse.sh`: without data protection
- [x] T006 [US2] `install.sh`: no renewal, removal of the LaunchAgent
- [x] T007 [US2] `app/SecretBar`: no profile and no renewal
- [x] T008 [US3] `tests/run.sh`: move of the checks 010, 011, 014, move from the file keychain
- [x] T009 [US2] `README.md`, `docs/claude-md-secrets.md`, `~/.claude/CLAUDE.md`
- [x] T010 2026-10-14, owner's Mac: `install.sh` removed the LaunchAgent `secretcli.renew`, deleted both
  profiles of the old helper, the `SecretStore*` builds and the files of its agent. `secret touchid status`:
  `store: secure enclave`, 68 secrets. Two `secret run` in a row — one Touch ID window. SecretBar
  is running, the icon shows grace, Spotlight — 68 entries. `tests/run.sh` passes.
