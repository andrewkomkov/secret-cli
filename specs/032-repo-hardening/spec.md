# Feature Specification: protection of the repo on GitHub

**Feature Branch**: `032-repo-hardening`

**Created**: 2026-11-11

**Status**: Draft 2026-11-11

**Input**: Owner: "is our repo on git great? Maybe add something useful from GitHub there".

Audit of 2026-11-11: `zizmor` gave 10 findings (8 high, 2 medium): actions without SHA, wide
permissions, a token in checkout. `main` has no protection. There is no `SECURITY.md` and no
private vulnerability reports.

The release has no attestation. CI runs only on `macos-15` (Swift 6.1), and the owner has
Swift 6.4. Because of this difference, the bug of 1.7.1 was found only in CI.

## Goal

The repo of a tool for secrets is itself closed against typical supply chain attacks. A user can
check that the workflow of this repo built the release tarball.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - workflows without extra permissions (Priority: P1)

1. **When** `zizmor` checks `.github/workflows`, **Then** there are no findings of level medium
   and high.
2. Each `uses:` is pinned by the full commit SHA. A comment next to it names the tag.
3. Permissions are given on the job level, not on the whole workflow. `checkout` does not keep
   the token.
4. Dependabot offers action updates once a week.

### User Story 2 - CI on two macOS versions (Priority: P1)

1. **When** a push or a PR happens, **Then** `tests/run.sh` passes on `macos-15` and `macos-26`.
2. CI checks `bin/secret` and the scripts with `shellcheck -S warning`.

### User Story 3 - verifiable release (Priority: P2)

1. **When** release-please made a release, **Then** the workflow creates a provenance
   attestation for the tag tarball.
2. `gh attestation verify secret-X.Y.Z.tar.gz -R andrewkomkov/secret-cli` passes. The README
   names the command.

### User Story 4 - security policy and protection of `main` (Priority: P2)

1. `SECURITY.md` says where to report a vulnerability and describes the threat model briefly.
2. Private vulnerability reporting is on.
3. Ruleset `main`: no force-push and no branch deletion. GitHub merges a PR only with green CI.
   The repo admin can bypass the rule (the owner pushes to `main` directly).
4. The branch is deleted after a PR merge. The empty Wiki is off.

## Requirements

- **FR-001**: actions pinned by SHA, permissions on the job level, `persist-credentials: false`.
- **FR-002**: `.github/dependabot.yml`, ecosystem `github-actions`, once a week.
- **FR-003**: CI matrix `macos-15`, `macos-26`. `shellcheck` in the Syntax step.
- **FR-004**: job `attest` in `release.yml`: downloads the tag tarball, `attest-build-provenance`.
- **FR-005**: `SECURITY.md` in English. README and README.ru: release verification.
- **FR-006**: repo settings through `gh api`: ruleset, private vulnerability reporting, delete
  branch on merge, wiki off.

## Success Criteria

- **SC-001**: `zizmor --offline .github/workflows` — 0 findings medium/high. `actionlint` is
  clean.
- **SC-002**: CI is green on both macOS versions.
- **SC-003**: next release: `gh attestation verify` passes (manual check).
- **SC-004**: `gh api repos/andrewkomkov/secret-cli/rulesets` shows the ruleset `main`.

## Scope

- The `secret` command does not change. This feature does not touch the tap formula.
- Major versions of actions are not bumped here: Dependabot will do it in separate PRs.
- `macos-27` is not in GitHub Actions as of 2026-11-11. We add it when it appears.
