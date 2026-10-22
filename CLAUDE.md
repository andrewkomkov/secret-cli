# secret-cli: rules for work on this repository

The rules for work with secrets are in `docs/claude-md-secrets.md`. `./install.sh --claude-hook`
imports them into `~/.claude/CLAUDE.md`.

## How to make a change

- Every change goes through spec-kit. Read `.specify/memory/constitution.md` first.
  Make a new folder `specs/NNN-slug/` with `spec.md`, `plan.md` and `tasks.md`. Point
  `.specify/feature.json` at that folder.
- Tick a task only after you check the code. A manual check gets a date in `tasks.md`.
- Run `tests/run.sh` before each commit. All checks must pass. The tests use a temporary
  keychain and a test build of the helpers. They do not touch the real store.
- Use Conventional Commits.

## What goes into the repository

The repository is public. Put only fictional data into files, tests, demo data and commits. Use
projects like `shop`, `billing`, `etl` and `wiki`. Do not write these items:

- the names of real secrets from `secret ls`.
- the names of work projects, hosts or companies.
- personal paths and work email addresses.

## Layout

- `bin/secret`: the command, one bash 3.2 file.
- `helper/secret-auth.swift`: the Touch ID helper for the file keychain.
- `helper/store/`: the helper of the Secure Enclave store. `bin/secret` calls it. The hook stops
  direct calls.
- `app/`: SecretBar, the menu bar app. It needs Xcode.
- `hooks/claude-pretooluse.sh`: the PreToolUse hook. `hooks/install-claude.sh` adds the hook and
  the rules import to `~/.claude`.
- `install.sh`: the install from a clone. The Homebrew formula is in
  `github.com/andrewkomkov/homebrew-secret`.

## Release

1. Push a tag `vX.Y.Z`.
2. In the tap, change `url` and `sha256` in `Formula/secret.rb`.
3. Run `brew install` and `brew test` for the formula.
