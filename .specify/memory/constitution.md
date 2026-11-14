<!--
Sync Impact Report
- Version: 2.5.0 → 3.0.0 (MAJOR: "Workflow", language and home of the project)
- Modified: specs and the constitution are in English. The public texts and the interface of
  SecretBar and of the Safari extension are in English, with the translations ru, de, fr, es, it,
  pt-PT and pl. The remote is the public repository `github.com/secretbar/secretbar`. The product
  name is SecretBar. The command `secret` keeps its name.
- Reason: the owner asked for a Product Hunt launch, an own GitHub org and an English repository
  with 5-6 European languages (2026-11-14). The constitution was translated from Russian with no
  change of meaning.

Previous report:
- Version: 2.4.0 → 2.5.0 (MINOR: "Technical constraints", post-quantum protection of the store)
- Modified: on macOS 26+, each value of the Secure Enclave store is sealed with two Secure Enclave
  keys: P-256 and ML-KEM-768. Both keys have `.userPresence`. One confirmation opens both. The
  helper always reads the old format (P-256 only). `secret touchid pq` converts an old store.
- Reason: the "store now, decrypt later" threat for the store file and the login keychain item.
  The owner asked for macOS 26 and 27 features (2026-11-11).

Previous report:
- Version: 2.3.0 → 2.4.0 (MINOR: principle II, secret lease for the agent)
- Added: a lease is an explicit set of names for up to 24 hours, with a new Touch ID for each
  lease. A locked screen and a sleep of the Mac keep the lease (they still end grace).
  `secret lease`, `secret lease --revoke`. `secret lock` also ends the lease. Leases work only in
  the Secure Enclave store.
- Reason: the owner wants the agent to work while the owner is away and the screen is locked
  (2026-11-04).

Previous report:
- Version: 2.2.1 → 2.3.0 (MINOR: "Workflow", language, CI, releases)
- Added: public texts (README, site, SecretBar interface) in English, with the `ru` translation.
  Specs and the constitution stayed in Russian. CI in GitHub Actions runs `tests/run.sh` on macOS
  for each push and PR. release-please makes the version, the tag and `CHANGELOG.md`. The release
  workflow updates the tap formula.
- Reason: the owner asked for the international market, CI and release-please (2026-10-23).

Previous report:
- Version: 2.2.0 → 2.2.1 (PATCH: "Workflow", agent rules)
- Modified: `~/.claude/CLAUDE.md` imports `docs/claude-md-secrets.md` with an `@` line. There is
  no copy of the section to compare.
- Reason: the section in `~/.claude/CLAUDE.md` was lost and the rules diverged (2026-10-22).

Previous report:
- Version: 2.1.0 → 2.2.0 (MINOR: public repository)
- Modified: "Workflow". The remote is a public repository on GitHub. The repository has no data
  of the owner or the employer: secret names, projects, hosts, personal paths.
- Added: install with Homebrew. Homebrew is an install method, not a dependency (III does not
  change).
- Reason: the owner asked for a public repository and a brew install (2026-10-22).

Previous report:
- Version: 2.0.0 → 2.1.0 (MINOR: command `secret gh`)
- Modified:
  - I. `secret gh` gives the value to `gh secret set` on stdin. GitHub keeps it encrypted and does
    not give it back.
  - II. The person confirms each push to GitHub in a window.
  - III. Only `secret gh` needs `gh` and the network. Without `gh`, the other commands work as
    before.
- Reason: the owner asked to write secrets to GitHub Actions secrets (2026-10-22).

Previous report:
- Version: 1.5.0 → 2.0.0 (MAJOR: data protection store removed)
- Modified: II, III, IV, V, "Technical constraints" without the data protection store. Two
  stores: Secure Enclave and the file keychain.
- Removed: data protection helper, Personal Team, provisioning profile, renewal,
  `migrate --vault` and `--dp`.
- Reason: the owner moved to the Secure Enclave store and asked to remove the old one
  (2026-10-14).

Previous report:
- Version: 1.4.1 → 1.5.0 (MINOR: third store, the Secure Enclave store)
- Modified:
  - II. Values of the Secure Enclave store are encrypted with a Secure Enclave key with
    `.userPresence`. Grace uses the same agent and the same rules.
  - III. `swiftc` from the Command Line Tools builds the Secure Enclave store helper.
  - IV. The test build of this helper uses a software key instead of the Secure Enclave.
  - V. Migration between the stores in both directions.
- Added: "Technical constraints": the Secure Enclave store.
- Reason: a Personal Team profile lives 7 days. Renewal depends on the Xcode sign-in and on the
  network. The owner wants a store that works for years without care (2026-10-14).
- Prototype 2026-10-14: a program with an ad-hoc signature made a key in the Secure Enclave. The
  key works only after a confirmation: Touch ID or Apple Watch.

Previous report:
- Version: 1.4.0 → 1.4.1 (PATCH: principle III, signature of SecretBar)
- Modified: III. SecretBar is signed with the owner's Apple Development certificate without a
  profile, or ad-hoc without a certificate. Reason: the App Intents service (`linkd`) does not
  read an app with an ad-hoc signature (research 014 R15).

Previous report:
- Version: 1.3.0 → 1.4.0 (MINOR: principle III, menu bar app)
- Modified: III. The SecretBar app is allowed. Xcode builds it, ad-hoc signature. The app works
  only through `secret` and the helper and does not access the keychain itself.
- Reason: the owner asked for an app (2026-10-07).

Previous report:
- Version: 1.2.1 → 1.3.0 (MINOR: "Technical constraints", meta items)
- Modified: "Technical constraints". The name, comment and expiry of a secret are in a meta item
  without `.userPresence`. The keychain asks for Touch ID also for the attributes of an item with
  `.userPresence` (research 011 R12).
- Reason: 3 Touch ID windows for one command (2026-10-07).

Previous report:
- Version: 1.2.0 → 1.2.1 (PATCH: principle II, grace mechanism)
- Modified: II. The keychain accepts a confirmed LAContext for about 10 minutes (research 010
  R11). So the agent keeps the values in memory during grace and gives them from there.
- Reason: a keychain Touch ID window every 10 minutes with a grace of 30 minutes (2026-10-07).

Previous report:
- Version: 1.1.0 → 1.2.0 (MINOR: principle II, sliding grace)
- Modified: II "The person confirms input and access". Grace in the data protection store counts
  from the last request. The total limit is 8 hours from Touch ID. A locked screen and a sleep of
  the Mac end grace.
- Added: none
- Removed: none
- Deferred: none
- Reason: the owner asked for fewer Touch ID windows (2026-10-07). A locked screen and a sleep end
  grace. This is stricter than the old 300 seconds from Touch ID.

Previous report:
- Version: 1.0.0 → 1.1.0 (MINOR: second store, principles II-V extended)
- Modified:
  - II "The person confirms input and access": in the data protection store the system checks
    Touch ID.
  - III "Only what macOS has": a helper .app is allowed. Xcode builds it, a free Personal Team
    signs it.
  - IV "Test on a temporary keychain" → "Test on a temporary store".
  - V "Compatibility": turn the new store on and off.
- Added: "Technical constraints": the data protection store
- Removed: none
- Deferred: none
- Reason: the SecKeychain* API and the file keychain are deprecated (since macOS 10.10).
- Probe 2026-10-07:
  - SecItemAdd with kSecUseDataProtectionKeychain: an ad-hoc signature gives -34018, an .app
    signed by a Personal Team gives 0.
  - A profile lives 7 days.
  - keychain-access-groups in the profile is the pattern TEAM.*. `.userPresence` protects the
    value, not the signature.
-->

# SecretBar Constitution

Rules for all work on the command `secret` and the app SecretBar. Check each feature in `specs/`
against this document before the first line of code.

## Core Principles

### I. The value of a secret does not go out
Only the commands made for it print a value to stdout (`get`; `copy` puts it on the clipboard).
A value never goes in process arguments (`argv` is visible in `ps`): to `security` it goes
through the stdin of `security -i`, to the helper through stdin or a pipe. Logs, error messages,
tests and documents contain the names of secrets, not values. A new command that shows a value is
a deviation. Record it in the `plan.md` of the feature. `secret gh` gives the value only to the
stdin of `gh secret set`.

### II. The person confirms input and access
The person types a new value in a hidden field (terminal or macOS window), not in the agent's
chat. The person unlocks the keychain and confirms Touch ID. The command does not keep the
keychain password. The command gives no way around these steps. In the mode
`SECRET_NO_DIALOG=1`, the command fails where a person is necessary.

The person confirms each push of a value to an external service (`secret gh`) in a macOS window.
The window shows the secret, the name in GitHub and the `gh` flags. Without the window the command
fails.

In the Secure Enclave store, a public key from the Secure Enclave encrypts each value. Its private
key works only after `.userPresence`: Touch ID, Apple Watch or the Mac password. A write needs no
Touch ID. A read needs Touch ID. An item of the file keychain keeps the wrapped Secure Enclave key
and the file key. Only the helper reads it without a question.

A helper agent process keeps the time without a new question (grace). After Touch ID the agent
reads the values and keeps them in its memory until grace ends. Hardened runtime without
`get-task-allow` closes this memory to a debugger. Grace slides: a new Touch ID question comes
after N seconds without requests. N is 3600 or less. The total limit is 8 hours from Touch ID. A
locked screen, a sleep of the Mac and `secret lock` end grace at once. A marker file does not
replace the confirmation of the system.

A lease is an explicit set of names for up to 24 hours, so that the agent can work while the owner
is away. Each lease needs a new Touch ID. The window shows the names and the term. Grace does not
replace it. The agent keeps the leased values in memory. Unlike grace, a locked screen and a sleep
of the Mac do not end the lease. These events end a lease: the end of the term,
`secret lease --revoke`, `secret lock`, a restart, a logout, a change or removal of a leased
secret. The term counts from Touch ID on a monotonic clock (it runs during sleep). Requests do not
extend it. With a locked screen, a read of a name outside the lease fails at once, with no window.
Leases work only in the Secure Enclave store.

### III. Only what macOS has
The command works on `bash` 3.2 and the system tools of macOS (`security`, `osascript`, `perl`,
`xxd`, `pbcopy`). It needs no Homebrew packages, Python libraries or network. Exception:
`secret gh` needs `gh` and the network. A compiled helper is allowed only if its source is in the
repository and `swiftc` from the Command Line Tools builds it. If the helper is not built, the
command works without the helper features.

`swiftc` from the Command Line Tools builds the Secure Enclave store helper. This helper has no
profile, entitlements or expiry. It is signed with the owner's Apple Development certificate,
otherwise ad-hoc. Hardened runtime is on. A paid developer account and a provisioning profile are
forbidden requirements.

Xcode builds the menu bar app SecretBar. It is signed with the owner's Apple Development
certificate, or ad-hoc without a certificate. Hardened runtime is on. It needs no entitlements or
profile. The app calls only `bin/secret` and the store helper. It does not access the keychain
itself and does not read values into its memory. Without the app, the command works the same.

### IV. Test on a temporary store
Each feature adds checks to `tests/run.sh`. The tests make their own keychain and remove it. The
working keychain `secrets` and the Keychain Access list do not change. The tests open no windows.
A check that needs a person (a window, Touch ID) is a manual check. Record it in `tasks.md` with
a date.

The test build of the Secure Enclave store helper keeps a software key and the file key in the
directory of the run. It does not touch the Secure Enclave or the keychain. The test Touch ID is an
answer from a file.

### V. Compatibility
Existing commands, the reference format `secret:NAME`, the account `secret-cli` and the default
keychain path do not change. A new feature is a new command or a new flag. A change of the
behavior of an existing command is a deviation, with the reason in `plan.md`.

`secret migrate --backup FILE` turns on the Secure Enclave store. `secret migrate --back` goes
back to the file keychain. The migration checks each value in the new store and only then switches
the command. Until the Secure Enclave store is on, the command works with the file keychain as
before.

## Technical constraints

- Keychain: `~/Library/Keychains/secrets.keychain-db`. Another one with `SECRET_KEYCHAIN`.
- Item: generic password, account `secret-cli`, service is the name, kind `secret-cli`, the
  comment is the attribute `icmt`.
- Secure Enclave store: the file `~/.local/share/secret/vault`. AES-GCM with the file key encrypts
  the whole file: the names are hidden, and the helper sees a replaced file. Inside, the public
  keys of the Secure Enclave also encrypt each value. On macOS 26+ this is a hybrid: ECDH P-256
  and ML-KEM-768. Both shared secrets go into one HKDF-SHA256, then AES-GCM. Without ML-KEM (old
  helper or old macOS) it is ECIES P-256. The helper reads both formats. `secret touchid pq`
  converts an old store to the hybrid. The file key and the wrapped Secure Enclave keys are in an
  item of the login file keychain: generic password, service `secret-cli.vault`, account
  `secret-cli`. The helper makes a new key only for an empty store. If the file exists and the item
  does not, the helper fails. `ls`, `has`, `check`, `note`, `expire` open the file with the file
  key, without Touch ID.
- Names: `^[A-Za-z_][A-Za-z0-9_.-]*$`. Values are one line.
- The command is one file `bin/secret`. `install.sh` installs it with a symlink.

## Workflow

- Each change goes through spec-kit: `specs/NNN-slug/` with `spec.md`, `plan.md`, `tasks.md`.
- A tick in `tasks.md` marks a checked fact: the code exists, the test passed.
- `tests/run.sh` passes in full before each commit.
- Commits use Conventional Commits. The remote is the public repository
  `github.com/secretbar/secretbar`. Files and commits contain no data of the owner: names of the
  owner's secrets, projects, hosts, personal paths.
- Specs, the constitution, README, the site and the interface are in English. The interface of
  SecretBar, the Safari extension and the site have the translations ru, de, fr, es, it, pt-PT and
  pl. A new interface string gets all translations in the same change. `README.ru.md` is a
  translation of README. The messages of the command `secret` are in English only.
- CI (`.github/workflows/ci.yml`) runs `tests/run.sh` on macOS for each push and PR. A red CI does
  not merge.
- release-please makes the release: a release PR with the version and `CHANGELOG.md`, after the
  merge the tag `vX.Y.Z` and the GitHub Release. The release workflow updates the formula in the
  tap. Nobody pushes a tag by hand.
- The agent rules are in `docs/claude-md-secrets.md`. `install.sh --claude-hook` imports them with
  an `@` line in `~/.claude/CLAUDE.md`.

## Governance

The constitution is above verbal agreements. Record a deviation in the `plan.md` of the feature in
the section "Complexity Tracking", with the reason. A change of the constitution is a separate
commit with a new version.

**Version**: 3.0.0 | **Ratified**: 2026-10-02 | **Last Amended**: 2026-11-14
