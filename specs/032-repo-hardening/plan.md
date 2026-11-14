# Implementation Plan: защита репы на GitHub

**Spec**: `specs/032-repo-hardening/spec.md`

## Technical Context

### Workflows

- `ci.yml`: `permissions: {}` на workflow, `contents: read` на job. Матрица `os: [macos-15,
  macos-26]`, `fail-fast: false`. Новый шаг `shellcheck -S warning` для `bin/secret`,
  `install.sh`, `hooks/install-claude.sh` и скриптов `build.sh`. В `tests/` есть предупреждения
  shellcheck, тесты в проверку не входят.
- `pages.yml`: права на job `deploy`.
- `release.yml`: права на каждый job. Новый job `attest`: `curl` скачивает tarball тега,
  `actions/attest-build-provenance` подписывает его. Формула tap берёт тот же tarball, поэтому
  `sha256` формулы и subject attestation совпадают.
- Все `uses:` — SHA последнего тега текущей мажорной версии (2026-11-11):
  checkout v4.4.0, configure-pages v5.0.0, upload-pages-artifact v3.0.1, deploy-pages v4.0.5,
  release-please-action v4.4.1, attest-build-provenance v4.2.2.
- `.github/dependabot.yml`: `github-actions`, weekly, префикс `ci`, одна группа.

### Настройки репы (`gh api`, не файлы)

- `PUT repos/{repo}/private-vulnerability-reporting`.
- `PATCH repos/{repo}`: `delete_branch_on_merge=true`, `has_wiki=false`.
- `POST repos/{repo}/rulesets`: target `branch`, `~DEFAULT_BRANCH`, rules `deletion`,
  `non_fast_forward`, `required_status_checks` (`tests on macos-15`, `tests on macos-26`),
  bypass — роль Repository admin (`actor_id` 5, `bypass_mode: always`).

## Constitution Check

- **I–II**: команда и значения не меняются. Секреты workflows те же (`HOMEBREW_TAP_DEPLOY_KEY`).
- **III**: зависимостей у команды нет. `shellcheck` нужен только CI.
- **IV**: `tests/run.sh` без изменений, CI гоняет его на двух версиях macOS.
- **V**: команды и форматы не меняются.

## Complexity Tracking

Нет отступлений.
