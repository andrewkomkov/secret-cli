# Implementation Plan: protection of the repo on GitHub

**Spec**: `specs/032-repo-hardening/spec.md`

## Technical Context

### Workflows

- `ci.yml`: `permissions: {}` on the workflow, `contents: read` on the job. Matrix `os: [macos-15,
  macos-26]`, `fail-fast: false`. New step `shellcheck -S warning` for `bin/secret`,
  `install.sh`, `hooks/install-claude.sh` and the `build.sh` scripts. `tests/` has shellcheck
  warnings, so the tests are not part of the check.
- `pages.yml`: permissions on the job `deploy`.
- `release.yml`: permissions on each job. New job `attest`: `curl` downloads the tag tarball,
  `actions/attest-build-provenance` signs it. The tap formula takes the same tarball, so the
  formula `sha256` and the attestation subject are the same.
- All `uses:` are the SHA of the last tag of the current major version (2026-11-11):
  checkout v4.4.0, configure-pages v5.0.0, upload-pages-artifact v3.0.1, deploy-pages v4.0.5,
  release-please-action v4.4.1, attest-build-provenance v4.2.2.
- `.github/dependabot.yml`: `github-actions`, weekly, prefix `ci`, one group.

### Repo settings (`gh api`, not files)

- `PUT repos/{repo}/private-vulnerability-reporting`.
- `PATCH repos/{repo}`: `delete_branch_on_merge=true`, `has_wiki=false`.
- `POST repos/{repo}/rulesets`: target `branch`, `~DEFAULT_BRANCH`, rules `deletion`,
  `non_fast_forward`, `required_status_checks` (`tests on macos-15`, `tests on macos-26`),
  bypass — the role Repository admin (`actor_id` 5, `bypass_mode: always`).

## Constitution Check

- **I–II**: the command and the values do not change. The workflow secrets are the same
  (`HOMEBREW_TAP_DEPLOY_KEY`).
- **III**: the command has no dependencies. Only CI needs `shellcheck`.
- **IV**: `tests/run.sh` without changes; CI runs it on two macOS versions.
- **V**: the commands and formats do not change.

## Complexity Tracking

No deviations.
