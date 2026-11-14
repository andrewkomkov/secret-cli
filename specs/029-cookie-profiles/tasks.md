# Tasks: cookies from all Safari profiles

**Input**: `specs/029-cookie-profiles/spec.md`

- [x] T001 [US1] `helper/cookies/main.swift`: `SECRET_TEST_SAFARI` instead of the file path, `Store`/`stores()`/`load()`, field `profile` in `Cookie`, code 77 on a directory without permission
- [x] T002 [US2] `pick()` — choice of one cookie: several paths/domains → code 3, otherwise the latest date; command `which`
- [x] T003 [US1] parse of `--profile ID` in argv, `list` with a profile column, `value`, `which`, `path` (`profile<TAB>file`)
- [x] T004 [US1][US2] `bin/secret`: `--profile` in `cookie ls`/`pull`, column `PROFILE`, pull through `which`→`value --profile`, comment with the profile, message 77 without a second `path`
- [x] T005 usage in `bin/secret`: `ls [--profile ID] DOMAIN`, `pull … [--profile ID]`, "the latest with several profiles"
- [x] T006 `tests/run.sh`: fixture directory `SECRET_TEST_SAFARI` (default + profile), cases 1–10 from the bug report
- [x] T007 README, README.ru, site, `docs/claude-md-secrets.md`: profiles, column `PROFILE`, `--profile`
- [ ] T008 manual on a real multi-profile Safari: `ls` sees the profile, `pull` takes the newest cookie, date — when done
