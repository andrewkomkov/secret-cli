# Implementation Plan: push of the tap formula with an SSH deploy key

**Spec**: `specs/028-tap-deploy-key/spec.md`

## Technical Context

### Job `formula` in `release.yml`

Before: clone over HTTPS with `HOMEBREW_TAP_TOKEN`. After: clone over SSH with a deploy key.

```yaml
env:
  DEPLOY_KEY: ${{ secrets.HOMEBREW_TAP_DEPLOY_KEY }}   # base64 of the private ed25519 key
steps:
  - name: No key
    if: env.DEPLOY_KEY == ''
    run: echo "::warning::HOMEBREW_TAP_DEPLOY_KEY is not set. Update the tap by hand."
  - name: Update the tap
    if: env.DEPLOY_KEY != ''
    run: |
      set -euo pipefail
      mkdir -p ~/.ssh && chmod 700 ~/.ssh
      printf '%s' "$DEPLOY_KEY" | base64 -d > ~/.ssh/tap && chmod 600 ~/.ssh/tap
      ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
      export GIT_SSH_COMMAND="ssh -i ~/.ssh/tap -o IdentitiesOnly=yes"
      url="https://github.com/$REPO/archive/refs/tags/$TAG.tar.gz"
      sha="$(curl -fsSL --retry 5 "$url" | sha256sum | cut -d' ' -f1)"
      git clone --depth 1 git@github.com:andrewkomkov/homebrew-secret.git tap
      cd tap
      sed -i -E "s|^  url \".*\"$|  url \"$url\"|; s|^  sha256 \".*\"$|  sha256 \"$sha\"|" Formula/secret.rb
      git config user.name "github-actions[bot]"
      git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
      git commit -am "secret $VERSION"
      git push
```

### Key provisioning (from the CLI, outside the repo)

1. `ssh-keygen -t ed25519 -N "" -C "homebrew-secret deploy (release.yml)" -f tapkey`.
2. `gh repo deploy-key add tapkey.pub -R andrewkomkov/homebrew-secret --allow-write --title "release.yml tap push"`.
3. `base64 < tapkey | secret set -c "<comment>" HOMEBREW_TAP_DEPLOY_KEY` — the private key goes
   into the store through a pipe, without argv. The value is one line (base64).
4. `secret gh HOMEBREW_TAP_DEPLOY_KEY -R andrewkomkov/secret-cli` — the owner confirms in the
   window.
5. Delete `tapkey` and `tapkey.pub`.

Check of the write permission before the release: `GIT_SSH_COMMAND` with the key + `git push` of
an empty commit to the tap, then a rollback. Or `ssh -i tapkey -T git@github.com` and a clone over
SSH.

## Constitution Check

- **I**: the private key goes into the store through a pipe; it does not get into argv or logs.
  base64 keeps the value on one line. `secret gh` gives it only to the stdin of
  `gh secret set`.
- **II**: `secret gh` reads the value — this is Touch ID and the push confirmation window. The
  owner confirms. The write `secret set` goes without Touch ID, as usual.
- **III**: `ssh-keygen`, `gh`, `base64` are in the system and already in the dependencies (`gh`
  is needed for `secret gh`).
- **IV**: `tests/run.sh` checks the `secret` command, not the workflow. The change of
  `release.yml` is checked on the next release — a manual check with a date in `tasks.md`.
- **V**: only the job `formula` changes. The `secret` commands, the reference format and the
  formula do not change.

## Complexity Tracking

| Deviation | Reason |
|---|---|
| Private key in base64 | The store keeps one-line values, and a PEM key has many lines. base64 is the bridge. |
| Change of the secret `HOMEBREW_TAP_TOKEN` → `HOMEBREW_TAP_DEPLOY_KEY` | An SSH key instead of a token. The old secret is missing anyway. |
