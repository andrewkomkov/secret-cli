# Tasks: Move secrets out of project .env files

**Input**: `specs/013-env-sweep/spec.md`

- [x] T001 `bin/secret`: `import --keys`, `import --ref`, check of the keys before the file changes
- [x] T002 `bin/secret`: `parse_line` errors with the line number, without the text
- [x] T003 `bin/secret`: `is_test_kc` without the working keychain file compares paths
- [x] T004 `tests/run.sh`: tests `013:`. 285 checks, 2026-10-07
- [x] T005 Move file by file, 2026-10-07. New secrets: 10. References to existing secrets instead of duplicates: 8. Each secret has a comment
- [x] T009 One `.env.local.test` skipped: the file is in git of a team repository, compose reads it through `env_file`. In one `.env` the tokens are empty
- [x] T010 Error during the move: `--ref` without `--keys` moved `PORT`, `HOST`, `USER` and one more key under generic names. The references are fixed, the generic names are deleted, `import` is fixed
- [x] T006 One `.env` in JSON format: 2 secrets, references in the JSON
- [x] T007 Old copy `.env.*.bak`: 4 secrets, the file is deleted (`rm -P`)
- [x] T011 Security check: test variables with the real helper led to the working store, `SECRET_PBCOPY` could take a value. Overrides work only with an existing test keychain and a test helper (`kind` = `test`). 292 checks, 2026-10-07
- [ ] T008 Backup `secret export` after the move. 2026-10-08 the owner refused to make a backup; the task stays open
