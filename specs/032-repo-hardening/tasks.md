# Tasks: защита репы на GitHub

**Input**: `specs/032-repo-hardening/spec.md`, `plan.md`

- [x] T001 [US1] actions закреплены SHA, права на job, `persist-credentials: false` в `ci.yml`, `pages.yml`, `release.yml`
- [x] T002 [US1] `.github/dependabot.yml` для `github-actions`
- [x] T003 [US2] матрица `macos-15`, `macos-26` и шаг `shellcheck` в `ci.yml`
- [x] T004 [US3] job `attest` в `release.yml`
- [x] T005 [US4] `SECURITY.md`; README и README.ru: проверка релиза, CI на двух версиях
- [x] T006 2026-11-11 проверка: `actionlint` чистый, `zizmor --offline` без находок, `shellcheck` чистый
- [x] T007 2026-11-11 [US4] настройки репы через `gh api`: private vulnerability reporting (`enabled: true`), delete branch on merge, wiki off
- [x] T008 2026-11-11 [US4] ruleset `main` (id 27046312): нет удаления и force-push, обязательны `tests on macos-15` и `tests on macos-26`, обход — роль admin
- [x] T009 2026-11-11 CI PR #10 зелёный на `macos-15` (4 мин) и `macos-26` (5 мин)
- [ ] T010 ручная: следующий релиз, `gh attestation verify` проходит. Дата — при выполнении

## Попутно

- [x] T011 2026-11-11: спеки 030 и 031 содержали настоящие имена сайта и секретов. Заменены на вымышленные (`portal.example.org`, `TAX_SESSION`). Коммит `docs(specs)`
