# Tasks: удалить хранилище data protection

**Input**: `specs/018-drop-data-protection/spec.md`

- [x] T001 [US1] `helper/store/main.swift`, `bin/secret`: `drop` и `migrate --drop-dp`
- [x] T002 [US1] 2026-10-14: `secret migrate --drop-dp` сверил 68 имён и после Touch ID удалил записи data protection (значения, служебные, политику)
- [x] T003 [US2] Конституция 2.0.0
- [x] T004 [US2] `helper/store/`: только Secure Enclave, `build.sh` на `swiftc`
- [x] T005 [US2] `bin/secret`, `completions/_secret`, `hooks/claude-pretooluse.sh`: без data protection
- [x] T006 [US2] `install.sh`: без продления, снятие LaunchAgent
- [x] T007 [US2] `app/SecretBar`: без profile и продления
- [x] T008 [US3] `tests/run.sh`: перенос проверок 010, 011, 014, переезд из файлового keychain
- [x] T009 [US2] `README.md`, `docs/claude-md-secrets.md`, `~/.claude/CLAUDE.md`
- [x] T010 2026-10-14, Mac владельца: `install.sh` снял LaunchAgent `secretcli.renew`, удалил оба
  profile старого helper, сборки `SecretStore*` и файлы его агента. `secret touchid status`:
  `store: secure enclave`, 68 секретов. Два `secret run` подряд — одно окно Touch ID. SecretBar
  запущен, значок показывает grace, Spotlight — 68 записей. `tests/run.sh` проходит.
