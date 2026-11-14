# Implementation Plan: a secret in GitHub Actions

**Spec**: `specs/021-github-actions-secrets/spec.md`

## Technical Context

- `bin/secret`: `cmd_gh`, `confirm`. The window is `osascript display dialog` with the buttons "Cancel" and
  "Send", "Cancel" by default.
- `gh secret set NAME` without `--body` reads the value from stdin. `gh` does the encryption for GitHub (libsodium
  sealed box). macOS has no XSalsa20, so the command does not do its own encryption.
- Tests: `SECRET_GH` is the path to a fake `gh`, `SECRET_CONFIRM=yes|no` is the answer of the window. Both
  variables work only through `test_override`, that is, only with the test keychain.
- SecretBar: in the log, the operation `gh` is called "send to GitHub".
- `completions/_secret`, `README.md`, `docs/claude-md-secrets.md`.

## Constitution Check

Constitution 2.1.0 allows this command:

- I: the value goes into the stdin of `gh`, it is not in `argv`.
- II: a human confirms each send in the window. Without the window — error.
- III: only `secret gh` needs `gh` and the network.
- IV: checks in `tests/run.sh` on a fake `gh`. The window and a live send are a manual check.
- V: the other commands do not change.

## Complexity Tracking

| Deviation | Reason |
|---|---|
| The value leaves the Mac for GitHub | Request of the owner. A human confirms the send, principles I–III in version 2.1.0 describe this |
