# Tasks: import of cookies from Safari into the store

**Input**: `specs/027-safari-cookie-import/spec.md`

- [x] T001 [US1] `helper/cookies/main.swift`: `.binarycookies` parser, subcommands `list DOMAIN` and `value DOMAIN NAME [PATH]`, test path from `SECRET_TEST_COOKIES`, code `77` on `EPERM`/`EACCES`
- [x] T002 [US1] `helper/cookies/build.sh` after the model of `helper/store/build.sh`: `Release`/`Test`, signature, `*.src-sha256`
- [x] T003 [US1] `bin/secret`: `cmd_cookie`, branch `cookie)` in the dispatcher, `secret cookie ls DOMAIN`, table output, Full Disk Access gate that opens the Settings pane
- [x] T004 [US2] `secret cookie pull DOMAIN NAME --as SECRET [--path PATH]`: value through a pipe into the store record, `-x` from the expiry date, comment `safari cookie DOMAIN NAME`, name check as in `set`
- [x] T005 `install.sh`: build of the cookies helper next to the store; without `swiftc`, a message that it is not available
- [x] T006 [US1][US2] `tests/run.sh`: synthetic `.binarycookies` as a fixture, check of the list of names and of the value extraction, without Safari and Full Disk Access
- [x] T007 README, README.ru, site `site/`: command `secret cookie`, the Full Disk Access requirement, the in-memory cookie limit
- [x] T008 `docs/claude-md-secrets.md`: rule for the agent on `secret cookie` (import of the session instead of reading the value)
- [x] T009 manual, 2026-11-03: `secret cookie ls google.com` on the real Safari gives the correct names, flags (`HSID` — only `HTTPOnly`, `NID`/`__Secure-1PSID` — `Secure,HTTPOnly`) and dates; the FDA gate gives code 77 without access. This found and fixed a bug: the page tag is big-endian (the parser read little-endian, and the fixture repeated the error). The owner runs `pull` into the real Secure Enclave with the target cookie; the pipeline is covered by tests in file mode.
