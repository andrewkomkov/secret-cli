# Implementation Plan: public repository and install through Homebrew

**Spec**: `specs/022-public-brew/spec.md`

## Technical Context

- `bin/secret` finds `build/` through the symlink, so it works from the Homebrew `libexec` without changes.
- Formula: `libexec.install` of the whole tree without `tests`, `specs`, `.specify`, `.claude`. Build
  `helper/store/build.sh Release libexec/build` and `swiftc helper/secret-auth.swift`. Symlink
  `bin/secret`, `zsh_completion`. `test do`: `secret help`, `secret ls` on a temporary keychain.
- `install.sh` stays for the install from a clone, SecretBar and the hook.
- SecretBar: `Paths.projects` reads the `UserDefaults` key `projectsDir`, otherwise `~`. The owner sets
  his value with the `defaults write` command.
- Cleanup: SecretBar demo data, README, `docs/claude-md-secrets.md`, tests, spec 013.
- The formula is only in the tap.
- Publication: a bundle of the old history in `~/secret-cli-history.bundle`, a new `.git`, one commit,
  `gh repo create --public`, tag `v1.0.0`, the tap with the formula and the sha256 of the tag archive.
- Constitution 2.2.0: "No remote is added" is replaced with "the remote is a public repository on GitHub,
  it holds no data of the owner".

## Constitution Check

- I, II: do not change.
- III: Homebrew is an install method, not a dependency. The command works on system utilities.
- IV: `tests/run.sh` passes. `brew install` and `brew test` are checked by hand.
- V: the commands and paths do not change. The default `projectsDir` gives `~` instead of the previous directory
  of the owner — a deviation, see below.

## Complexity Tracking

| Deviation | Reason |
|---|---|
| The SecretBar reference search path became a setting | The previous path named the employer's directory. The owner sets it in `projectsDir` |
| Remote on GitHub | Request of the owner, constitution 2.2.0 |
