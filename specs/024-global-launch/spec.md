# Feature Specification: launch on the international market

**Feature Branch**: `024-global-launch`. The work goes on in `main`.

**Created**: 2026-10-23

**Status**: In progress: T013 is left, a manual step of the owner

**Input**: The owner: "let's take it to the international market, and a promo landing page with motion design, and CI on
Actions, and release-please".

## User Scenarios & Testing *(mandatory)*

### User Story 1 - English first (Priority: P1)

A developer from any country opens the repository, reads the README, installs the command and SecretBar.

1. **When** a human opens the repository, **Then** the README is in English. The Russian version is `README.ru.md`,
   with links between the versions in the header.
2. **When** the macOS language is not Russian, **Then** SecretBar shows the interface in English.
3. **When** the macOS language is Russian, **Then** SecretBar shows the interface in Russian, as before.
4. The messages of the `secret` command are already in English and do not change.
5. `secret version` and `secret --version` print the version.

### User Story 2 - CI and releases (Priority: P1)

1. **When** a push to `main` or a pull request comes, **Then** GitHub Actions on macOS runs
   `tests/run.sh` (with the helper and SecretBar) and checks the syntax of the scripts. A red run is visible in the PR.
2. **When** `feat`/`fix` commits come to `main`, **Then** release-please opens a release PR with
   the new version and `CHANGELOG.md`.
3. **When** the owner merges the release PR, **Then** the tag `vX.Y.Z` and a GitHub Release appear. The formula in
   the tap gets the new `url` and `sha256`, the tap CI runs `brew install` and `brew test`.
4. **When** the repository has no secret `HOMEBREW_TAP_TOKEN`, **Then** the formula step is skipped with
   a warning, the release does not fail.

### User Story 3 - Landing page (Priority: P2)

1. **When** a human opens `https://andrewkomkov.github.io/secret-cli/`, **Then** the page in
   English explains the product in one screen: the agent works with names, it does not see values.
2. Animations show the flow: hidden input → Secure Enclave → `run --mask` → `***`. The terminal in
   the hero types commands. Blocks appear on scroll.
3. **When** "reduce motion" is on in the system, **Then** the animations are off, all text is visible.
4. The page works at phone width, in the light and dark theme, without a build and without trackers.
5. **When** a push to `main` comes in `site/`, **Then** Actions publishes the page to GitHub Pages.

### Edge Cases

- A fork without secrets: CI passes, the formula step is skipped.
- The SecretBar test on a runner without an Apple Development certificate: ad-hoc signature, selftest passes.
- An interface string without a translation: SecretBar shows the English text.

## Requirements *(mandatory)*

- **FR-001**: README in English, `README.ru.md` in Russian, the same content.
- **FR-002**: SecretBar: the development language is English, a String Catalog with the `ru` translation for each
  string of the interface, App Intents and notifications.
- **FR-003**: `secret version` prints `secret X.Y.Z`. The version line in `bin/secret` is marked for
  release-please.
- **FR-004**: `.github/workflows/ci.yml`: `tests/run.sh` on a macOS runner, `bash -n` for the scripts.
- **FR-005**: `.github/workflows/release.yml`: release-please (type `simple`, tags `vX.Y.Z`), then
  the update of the formula in the tap with the token `HOMEBREW_TAP_TOKEN`.
- **FR-006**: CI in the tap: `brew install --build-from-source`, `brew test`, `brew audit --strict`.
- **FR-007**: `site/`: a static page (HTML, CSS, JS without a build), animations in CSS and the
  Web Animations API, `prefers-reduced-motion`, light and dark theme, SecretBar screenshots.
- **FR-008**: `.github/workflows/pages.yml` publishes `site/` to GitHub Pages.
- **FR-009**: the new files have no data of the owner (constitution, "Workflow").

## Success Criteria *(mandatory)*

- **SC-001**: CI is green on `main`.
- **SC-002**: release-please opened a release PR.
- **SC-003**: the page opens at the Pages address, Lighthouse: accessibility 90 or higher.
- **SC-004**: SecretBar with `-AppleLanguages (en)` and `(ru)` has no strings of the other language (screenshots).

## Assumptions

- The specs and the constitution stay in Russian: they are the working documents of the owner.
- The owner creates the token for the tap (fine-grained PAT, Contents: write on `homebrew-secret`) and stores it
  with the command `secret gh HOMEBREW_TAP_TOKEN -R andrewkomkov/secret-cli`.
