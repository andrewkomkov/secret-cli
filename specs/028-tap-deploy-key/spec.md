# Feature Specification: push of the tap formula with an SSH deploy key

**Feature Branch**: `028-tap-deploy-key`. The work goes on in `main`.

**Created**: 2026-11-03

**Status**: Draft 2026-11-03

**Input**: The owner chose an SSH deploy key instead of a PAT: "yes, let's do it over ssh".
GitHub does not issue a PAT through the API, but a deploy key can be set up fully from the CLI.
The goal is to bring back the automatic update of the formula in the tap on release, without a
token from the browser.

## Context and scope

- The job `formula` in `.github/workflows/release.yml` clones the tap over HTTPS with the token
  `HOMEBREW_TAP_TOKEN`. Now the secret is missing, and the job skips the update.
- New path: a deploy key with write permission on `andrewkomkov/homebrew-secret`. The public
  part is in the tap, the private part is in the store and in GitHub Actions.
- A private PEM key has many lines, and the store keeps one-line values. So the key goes in
  base64: one line in the store and in Actions, and the workflow decodes it back.
- The feature changes only the job `formula`. The formula build (`def install`) and the `secret`
  commands stay the same.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - the release updates the tap over SSH (Priority: P1)

1. **When** release-please makes a release and the secret `HOMEBREW_TAP_DEPLOY_KEY` is set,
   **Then** the job `formula` clones the tap over SSH with the deploy key, changes `url` and
   `sha256`, commits and pushes.
2. **When** the secret is empty, **Then** the job prints a warning and skips the update, as now.
3. **When** the key has no write permission, **Then** `git push` fails and the job turns red —
   no silent failure.

### User Story 2 - key provisioning from the CLI (Priority: P1)

1. **When** the owner sets up the key, **Then** `ssh-keygen` makes an ed25519 pair without a
   passphrase, and `gh repo deploy-key add --allow-write` puts the public part into the tap.
2. **When** the key is ready, **Then** the base64 of the private part is in the store under
   `HOMEBREW_TAP_DEPLOY_KEY`, and `secret gh` sends it to the Actions of the repository
   `secret-cli`.
3. The local key files are deleted after the provisioning. The private key does not go to
   stdout or logs.

## Requirements *(mandatory)*

- **FR-001**: the job `formula` uses an SSH deploy key instead of an HTTPS token. The env
  variable is `HOMEBREW_TAP_DEPLOY_KEY` (base64 of the private key).
- **FR-002**: the job steps: decode the key into `~/.ssh`, add `github.com` to `known_hosts`,
  set `GIT_SSH_COMMAND`, clone `git@github.com:andrewkomkov/homebrew-secret.git`, change the
  formula, commit and push.
- **FR-003**: the "no key" branch prints a warning and exits; it does not do the update.
- **FR-004**: the deploy key has write permission only on `andrewkomkov/homebrew-secret`.
- **FR-005**: the private key is kept in the store and in Actions as base64. The value does not
  go into argv or logs.

## Success Criteria *(mandatory)*

- **SC-001**: the next release updates `url` and `sha256` in the tap without a manual change.
- **SC-002**: the key provisioning goes fully from the CLI, without a browser.
- **SC-003**: the private key stays out of stdout and logs; `gh secret list` shows only the name.
