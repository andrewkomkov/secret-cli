# Feature Specification: major versions of actions

**Feature Branch**: `037-actions-major`

**Created**: 2026-11-14

**Status**: Done 2026-11-14

**Input**: PR #15 from Dependabot. Owner: "yes - go ahead".

## Goal

Move to the new major versions of five actions. The workflows work as before.

| Action | Before | After |
|---|---|---|
| actions/checkout | 4.4.0 | 7.0.1 |
| actions/configure-pages | 5.0.0 | 6.0.0 |
| actions/upload-pages-artifact | 3.0.1 | 5.0.0 |
| actions/deploy-pages | 4.0.5 | 5.0.1 |
| googleapis/release-please-action | 4.4.1 | 5.0.0 |

## Breaking changes and check

- All five: Node 24. The GitHub runner supports it.
- checkout 7: does not check out a PR from a fork for `pull_request_target` and `workflow_run`.
  We do not have these triggers.
- upload-pages-artifact 4: does not put dotfiles into the artifact. `site/` has no dotfiles.
- release-please-action 5: only Node 24 and release-please 17.6.0. The inputs `config-file` and
  `manifest-file` did not change.

## Requirements

- **FR-001**: each action is pinned by SHA; the SHA matches the tag in the action repository.
- **FR-002**: `persist-credentials: false` and the job permissions do not change.

## Success Criteria

- **SC-001**: CI of PR #15 passes on macos-15 and macos-26.
- **SC-002**: after the merge, `release.yml` and `pages.yml` pass on `main`.
