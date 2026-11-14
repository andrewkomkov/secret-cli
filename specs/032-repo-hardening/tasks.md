# Tasks: protection of the repo on GitHub

**Input**: `specs/032-repo-hardening/spec.md`, `plan.md`

- [x] T001 [US1] actions pinned by SHA, permissions on the job, `persist-credentials: false` in `ci.yml`, `pages.yml`, `release.yml`
- [x] T002 [US1] `.github/dependabot.yml` for `github-actions`
- [x] T003 [US2] matrix `macos-15`, `macos-26` and the `shellcheck` step in `ci.yml`
- [x] T004 [US3] job `attest` in `release.yml`
- [x] T005 [US4] `SECURITY.md`; README and README.ru: release verification, CI on two versions
- [x] T006 2026-11-11 check: `actionlint` is clean, `zizmor --offline` has no findings, `shellcheck` is clean
- [x] T007 2026-11-11 [US4] repo settings through `gh api`: private vulnerability reporting (`enabled: true`), delete branch on merge, wiki off
- [x] T008 2026-11-11 [US4] ruleset `main` (id 27046312): no deletion and no force-push, `tests on macos-15` and `tests on macos-26` are required, bypass — the admin role
- [x] T009 2026-11-11 CI of PR #10 is green on `macos-15` (4 min) and `macos-26` (5 min)
- [x] T010 manual, 2026-11-14: release 1.8.0, the job `attest` passed, `gh attestation verify secret-1.8.0.tar.gz -R andrewkomkov/secret-cli` gives code 0. The tap formula updated itself, `sha256` matches the tarball

## Along the way

- [x] T011 2026-11-11: specs 030 and 031 contained the real names of the site and of the secrets. They were replaced with fictional ones (`portal.example.org`, `TAX_SESSION`). Commit `docs(specs)`
