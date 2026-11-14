# Tasks: a secret in GitHub Actions

**Input**: `specs/021-github-actions-secrets/spec.md`

- [x] T001 Constitution 2.1.0
- [x] T002 [US1] `bin/secret`: `cmd_gh`, `confirm`, help
- [x] T003 [US2] `hooks/claude-pretooluse.sh`: `SECRET_GH`, `SECRET_CONFIRM` only for tests
- [x] T004 [US1] `completions/_secret`, SecretBar: operation name in the log
- [x] T005 `tests/run.sh`: 15 checks of 021 on a fake `gh`
- [x] T006 `README.md`, `docs/claude-md-secrets.md`
- [ ] T007 Manual check: the confirmation window, `secret gh` to a test repository, `gh secret list` shows the name
