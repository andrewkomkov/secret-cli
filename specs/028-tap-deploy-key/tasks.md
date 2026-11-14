# Tasks: push of the tap formula with an SSH deploy key

**Input**: `specs/028-tap-deploy-key/spec.md`

- [x] T001 [US1] `.github/workflows/release.yml`: job `formula` — SSH deploy key instead of an HTTPS token, env `HOMEBREW_TAP_DEPLOY_KEY`, "no key" branch with a warning
- [x] T002 [US2] provisioning: `ssh-keygen` ed25519, `gh repo deploy-key add --allow-write` on `homebrew-secret`
- [x] T003 [US2] base64 of the private key in the store under `HOMEBREW_TAP_DEPLOY_KEY` (through a pipe, without argv)
- [x] T004 [US2] `secret gh HOMEBREW_TAP_DEPLOY_KEY -R andrewkomkov/secret-cli` (the owner confirms in the window), delete the local key files
- [x] T005 check of the key write permission: clone of the tap over SSH and write access (without a release)
- [x] T006 manual, 2026-11-03: release 1.4.0 — the job `formula` itself updated url and sha256 in the tap with the SSH deploy key (commit "secret 1.4.0"), the formula moved to v1.4.0, the cookies line was kept, the tap CI brew install is green.
