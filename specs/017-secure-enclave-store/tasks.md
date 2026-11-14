# Tasks: Secure Enclave store without a signature expiry

**Input**: `specs/017-secure-enclave-store/spec.md`

- [x] T001 [US1] `helper/store/main.swift`: storage in a file under the `VAULT` flag, keys, ECIES,
  confirmation through `check`
- [x] T002 [US1] `helper/store/build-vault.sh`, `install.sh`: `swiftc` build, signature
- [x] T003 [US1] `bin/secret`: `vault` mode, helper selection, `touchid status`, no profile
- [x] T004 [US2] `bin/secret`: `migrate --vault`, `--dp`, `--back` from the new store
- [x] T005 [US1] `app/SecretBar`: `vault` mode, helper by the mode, no profile warning
- [x] T006 [US3] `tests/run.sh`: tests of the new store on the test build
- [x] T010 [US3] `helper/store/main.swift`, `bin/secret`, `tests/run.sh`: protection of the
  keychain item (silent read, `touchid repair`, grace in the item, `.userPresence` check)
- [x] T007 `README.md`, `docs/claude-md-secrets.md`, `~/.claude/CLAUDE.md`: the new store
- [x] T008 Live check 2026-10-14 on the release build with an Apple Development signature. The
  store held only the item `LIVE_CHECK_017`, then the agent deleted it.
  - New store: the Secure Enclave key and the login keychain item are created without a window.
  - Read: one window, the value matched. Second read in grace: 0 s, no window.
  - Helper rebuild: the keychain item is read without a prompt.
  - ACL of the item: `decrypt` without a password only for `secret-vault` by the signature requirement.
  - Another program overwrote the item. The first version showed the keychain password window, the owner
    clicked "Cancel". After `SecKeychainSetUserInteractionAllowed(false)` the helper refuses in 0 s,
    no window.
  - `repair`: one window, a new item, the value is read.
- [x] T009 Move of the owner 2026-10-14: `secret migrate --vault` — 68 secrets, two windows, each
  value compared (SC-001). `secret run` with two names in grace — 0 windows (SC-002).
  `touchid status`: `store: secure enclave`, no profile. SecretBar gets the status from the new
  helper (the icon is open during grace), Spotlight — 68 entries. SC-003 (work after October 19)
  will check itself: the helper has no profile.
