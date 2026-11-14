<div align="center">

# SecretBar

**Secrets your AI agent uses by name and never sees. The command `secret` and the menu bar app SecretBar keep them in the Secure Enclave of your Mac.**

**English** · [Русский](README.ru.md) · [Website](https://secretbar.github.io)

![macOS](https://img.shields.io/badge/macOS-only-000000?logo=apple&logoColor=white)
![bash 3.2](https://img.shields.io/badge/bash-3.2-4EAA25?logo=gnubash&logoColor=white)
![deps](https://img.shields.io/badge/dependencies-none-blue)
[![CI](https://github.com/secretbar/secretbar/actions/workflows/ci.yml/badge.svg)](https://github.com/secretbar/secretbar/actions/workflows/ci.yml)
[![release](https://img.shields.io/github/v/release/secretbar/secretbar?sort=semver)](https://github.com/secretbar/secretbar/releases)
![license](https://img.shields.io/badge/license-MIT-lightgrey)

[Quick start](#quick-start) ·
[How it works](#how-it-works) ·
[Features](#features) ·
[Commands](#commands) ·
[Security](#security) ·
[FAQ](#faq)

</div>

---

```console
$ secret ask GITHUB_TOKEN "Token from github.com/settings/tokens"   # macOS dialog, hidden input
stored: GITHUB_TOKEN

$ secret run --mask GITHUB_TOKEN -- sh -c 'echo "token is $GITHUB_TOKEN"'
token is ***

$ secret ls -l
SHOP_DB_PASSWORD        2026-12-31  shop: PostgreSQL password
GITHUB_TOKEN                        GitHub personal token for gh
```

Passwords, tokens and API keys live in a Secure Enclave store. A key from the chip of your Mac
encrypts each value, and the value opens only after Touch ID or Apple Watch. The `secret` command puts
them into the environment of a process by name. A human types a value into a dialog with a hidden
field, never into the chat with the agent. The agent works with names only.

<p align="center"><img src="docs/img/main-dark.png" width="760" alt="SecretBar main window"></p>

## Quick start

```sh
brew install secretbar/tap/secretbar   # the command, both helpers, zsh completion
secret init                               # create the keychain and set its password
secret ask MY_TOKEN                       # store the first secret
secret run --mask MY_TOKEN -- ./deploy.sh
```

The Claude Code hook and the SecretBar menu bar app (it needs Xcode):

```sh
"$(brew --prefix secretbar)/libexec/install.sh" --claude-hook --app
```

From source:

```sh
git clone https://github.com/secretbar/secretbar && cd secretbar
./install.sh --claude-hook     # symlink in ~/.local/bin, helpers, zsh completion, hook
```

Only macOS is necessary. The command runs on `bash` 3.2 and the system `security`, `osascript`,
`perl`, `openssl` and `xxd`. Touch ID in the file keychain needs `swiftc` from the Command Line
Tools (`xcode-select --install`).

Without an Apple Development certificate the helpers get an ad-hoc signature. After an upgrade
that changes the Secure Enclave helper, the command asks for `secret touchid repair`: one touch.

### Secure Enclave store

`swiftc` from the Command Line Tools builds the helper `build/secret-vault`. Xcode, an Apple ID
or a provisioning profile are not necessary. Its signature does not expire. If the system has an
Apple Development certificate, `install.sh` signs the helper with it: then a rebuild keeps the
access to the key.

```sh
./install.sh                                 # builds build/secret-vault
secret migrate --backup ~/secrets-before.bak # backup, move, verify, delete the old copies
secret touchid status                        # store: secure enclave
secret migrate --back                        # back to the file keychain
```

- The file `~/.local/share/secret/vault` is encrypted as a whole: names and comments are hidden.
- Each value inside is encrypted again with a public key from the Secure Enclave. The private key
  works only after Touch ID, Apple Watch or the Mac password. Writes need no Touch ID.
- The file key and the grace state are in an item of the login keychain. Only the helper reads
  it without a question.
- If another program changes that item, the helper stops and shows no password dialog.
  `secret touchid repair` restores the item from the file after one touch.
- Grace slides: 30 minutes without requests, 8 hours at most. A screen lock, sleep or
  `secret lock` ends it at once.

## How it works

```mermaid
sequenceDiagram
    autonumber
    actor H as Human
    participant A as Agent
    participant S as secret
    participant K as Secure Enclave store
    A->>S: secret ask DB_PASS
    S->>H: macOS dialog, hidden field
    H->>S: value
    S->>K: write (through stdin, not argv)
    A->>S: secret run --mask DB_PASS -- psql
    S->>H: Touch ID: "use DB_PASS for psql"
    S->>K: read
    S->>S: value into the environment of psql
    S-->>A: output of psql, value replaced with ***
```

The value goes around the context of the agent both on write and on read. If the agent tries to
print a value anyway (`secret get`, `cat .env`, `security find-generic-password -w`), the Claude
Code hook stops the command.

## Features

| | |
|---|---|
| **Hidden input** | `secret ask` opens a macOS dialog. A human types the value, the agent sees only `stored: NAME` |
| **Generation** | `secret gen` makes a random password directly in the store; nobody sees it |
| **Output masking** | `secret run --mask` replaces values with `***` in stdout and stderr, also in base64 and URL encoding. Always on under Claude Code |
| **References in `.env`** | `TOKEN=secret:MY_TOKEN` instead of the value; `secret import` moves an existing `.env` |
| **GitHub Actions** | `secret gh NAME -R owner/repo` sends a value to `gh secret set` through stdin, after a confirmation dialog |
| **Safari cookies** | `secret cookie pull` moves a session cookie from Safari into the store, so the agent acts on a site without an API. The value never reaches the chat |
| **Access log** | `secret log`: who (`agent` or `human`), when, which secrets. No values in the log |
| **Claude Code hook** | stops agent commands that would print values |
| **Touch ID** | in the Secure Enclave store the key from the chip works only after Touch ID or Apple Watch |
| **Clipboard** | `secret copy` clears the clipboard after 30 seconds |
| **Expiry** | `-x 2026-12-31`, `secret ls --expiring`, a warning on use |
| **Search by meaning** | `secret ls --ask "smtp of billing"`: the on-device model of macOS 27, names and comments only, no network |
| **Backup** | `secret export` / `restore`: one file, AES-256 under a separate password |
| **Menu bar app** | SecretBar: ⌥⌘S quick search, Spotlight, a card for each secret, activity |
| **Completion** | secret names on Tab in zsh, without a request to the store |

## Commands

**Every day**

```sh
secret ask NAME ["hint"]             # store a value through a dialog
secret run --mask NAME -- cmd        # run cmd with the secret in its environment
secret run --mask -e .env -- cmd     # the same, secret:NAME references from .env
secret ls -l                         # names, expiry dates, comments
secret copy NAME                     # to the clipboard for 30 seconds
```

**Items**

```sh
secret gen -l 32 -s symbols -c "comment" NAME
secret set -c "comment" -x 2026-12-31 NAME < file
secret note NAME "new comment"
secret expire NAME 2027-01-31        # or none
secret mv OLD NEW
secret rm NAME
```

**GitHub Actions**

```sh
secret gh DEPLOY_KEY -R owner/repo             # confirmation dialog, then gh secret set
secret gh PROD_DB_URL DATABASE_URL -R owner/repo -e production
```

GitHub keeps the value encrypted and never gives it back. The command needs `gh` after
`gh auth login`. Only `secret gh` uses the network.

**Safari cookies**

```sh
secret cookie ls grafana.example.com                                   # names, paths, flags, expiry, profile; no values
secret cookie pull grafana.example.com grafana_session --as SHOP_GRAFANA_SESSION
secret cookie pull example.com sid --path /app --as SHOP_SID           # when several paths match
secret cookie pull example.com sid --profile PROFILE --as SHOP_SID     # one Safari profile only
secret cookie pull example.com --all --as SHOP_JAR                     # all persistent cookies of the domain, one jar
```

`pull` writes the value to the store through a pipe, with the comment `safari cookie DOMAIN NAME, profile PROFILE`
and the expiry date of the cookie, so `secret ls --expiring` warns in time. Notes:

- Safari keeps its cookies in a file that macOS protects. Give **Full Disk Access** to the app
  that runs `secret` (Terminal, iTerm). Without it the command prints the path of the file and
  opens the settings pane.
- `secret` reads all Safari profiles: the default one and each profile in `WebsiteDataStore`. `ls` shows the
  profile in the `PROFILE` column (`default` or the profile ID). If the same cookie is in several
  profiles, `pull` takes the one that expires last. `--profile ID` reads one profile only.
- Only persistent cookies (with an expiry date) are in the file. A cookie that lives until the tab
  closes (in memory) is not there, and `sessionStorage` and `localStorage` are not cookies.
- Safari only. The cookies helper is built by `./install.sh` with `swiftc`; without it the
  command says it is not available and the other commands work.

**Session cookies and the cookie jar**

Some sites (ASP.NET: `ASP.NET_SessionId`; also `JSESSIONID`, `PHPSESSID`) keep the session in an
HttpOnly cookie without an expiry date. Safari never writes it to disk, so `pull NAME` cannot get it.
A Safari extension (`app/extension`) reads these cookies from your real Safari session and sends
them to a loopback daemon, which calls `secret cookie import`; `import` also works with any
Netscape cookie jar on stdin. All cookies of
the domain are stored as one cookie jar. `pull DOMAIN --all` stores the persistent ones from the
Safari files.

```sh
secret cookie pull shop.example.com --all --as SHOP_SESSION     # persistent cookies, one jar
some-exporter | secret cookie import --as SHOP_SESSION          # a jar on stdin (the Safari extension will call this)
secret cookie ls --jar SHOP_SESSION        # name, domain, flags, expiry; no values
secret run --mask --cookie-jar SHOP_SESSION --update -- \
  sh -c 'curl -s -b "$SECRET_COOKIE_JAR" -c "$SECRET_COOKIE_JAR" https://shop.example.com/MainPage.aspx'
```

`$SECRET_COOKIE_JAR` is set in the command's environment, so wrap the command in `sh -c '...'`:
the shell that runs `secret run` would expand it to empty too early.

- The jar is a Netscape cookie file (curl, wget, Python `http.cookiejar`; HttpOnly lines start with
  `#HttpOnly_`), stored as base64 in one secret. The comment is `cookie jar DOMAIN via safari
  extension, N cookies, session-only: a,b`. The expiry is the earliest of the persistent cookies;
  with only session cookies there is none.
- `run --cookie-jar` writes the jar to a temp file (mode 600), puts the path in `$SECRET_COOKIE_JAR`
  and deletes the file after the command, also on a signal. `--update` saves the jar back when the
  server set new cookies. `--mask` covers the value of each cookie.
- The Claude Code hook stops `cat`, `cp` and similar on `$SECRET_COOKIE_JAR`.
- `--mask` does not mask a value shorter than 4 characters (it would turn `302` into `3***2`) and
  prints `mask skipped for short value NAME` once.
- The bridge daemon `secret-bridge` (built by `./install.sh` with `swiftc`) listens on `127.0.0.1`
  only (port 17659 by default) and accepts `POST /jar?as=NAME` with the header `X-Secret-Token`.
  With the right token it passes the body (a Netscape jar) to `secret cookie import --as NAME` on
  stdin; a wrong or missing token gives 401/403, another path 404. It never logs the body.

  ```sh
  secret cookie bridge token    # makes ~/.local/state/secret/bridge.json (0600) once, prints the token
  secret cookie bridge start    # runs the daemon in the background
  secret cookie bridge stop
  ```

  Manual steps for the extension (its Xcode wrapper comes next): enable it in Safari Settings,
  Extensions; allow it on the site (per-site access to cookies); open its settings and paste the
  token from `secret cookie bridge token`, the name of the secret and the port; log in on the
  site and click the extension button. The jar goes extension, loopback, daemon, `import` stdin.
- Use `pull` for persistent cookies and the Safari extension (`import`) for session cookies. If
  `pull` or `cookie ls` sees a known session cookie, it prints `session cookie not on disk: capture
  it with the Safari extension (secret cookie import --as NAME)`.

<details>
<summary><b>Full reference</b></summary>

| Command | What it does |
|---|---|
| `secret init` | create the keychain, set its password, add it to Keychain Access |
| `secret unlock`, `secret lock` | unlock, lock |
| `secret ask NAME [TEXT]` | a macOS dialog with hidden input; the value is stored as NAME |
| `secret set [-c COMMENT] [-x YYYY-MM-DD] NAME [VALUE]` | store from stdin, from the terminal (hidden input) or from VALUE |
| `secret gen [-l LEN] [-s alnum\|symbols\|hex] [-c COMMENT] [-f] NAME` | a random value, LEN 8–256 (default 32); the value is not printed |
| `secret note NAME [COMMENT]` | set or show the comment |
| `secret expire NAME YYYY-MM-DD\|none` | set or remove the expiry date |
| `secret ls [-l]` | names; `-l` adds the expiry date and the comment |
| `secret ls --expiring [DAYS]` | expired and expiring within DAYS days (default 30) |
| `secret ls --ask QUERY [-l]` | names that fit QUERY in any language ("database password of the shop"); the on-device model of macOS 27 (`fm`) sees only names and comments |
| `secret has NAME` | exit 0 if the secret exists; prints nothing |
| `secret get NAME` | print the value |
| `secret copy NAME [SECONDS]` | to the clipboard; after SECONDS (default 30) the clipboard is cleared if it still holds the value |
| `secret gh NAME [GH_NAME] [-R OWNER/REPO] [-e ENV] [-o ORG [-v VISIBILITY]]` | store the value as the GitHub Actions secret GH_NAME (default NAME) through `gh secret set`. A human confirms each push in a dialog. Flags go to `gh` unchanged; `-b` and `-f` are refused |
| `secret cookie ls [--profile ID] DOMAIN` | list the Safari cookies of DOMAIN in all profiles (a cookie of `.example.com` also covers its subdomains): name, path, `Secure`/`HTTPOnly`, expiry, profile. Prints no values. Needs Full Disk Access |
| `secret cookie pull DOMAIN NAME --as SECRET [--path PATH] [--profile ID]` | store the value of the Safari cookie as SECRET with the comment `safari cookie DOMAIN NAME, profile PROFILE` and the cookie expiry date. `--path` picks one of several cookies with the same name. With several profiles, the cookie that expires last; `--profile` picks a profile |
| `secret cookie pull DOMAIN --all --as SECRET [--profile ID]` | store all persistent Safari cookies of DOMAIN as one cookie jar |
| `secret cookie bridge token\|start\|stop` | the loopback daemon for the Safari extension: `token` prints the pairing token (creates `bridge.json`, 0600), `start` and `stop` run and end the daemon |
| `secret cookie import --as SECRET [--domain D] [--replace]` | read a Netscape cookie jar from stdin and store it as a cookie jar SECRET (base64); the Safari extension is the source for session-only cookies. If SECRET exists, the cookies are merged into it (key `domain|path|name`, the new one wins); the merge reads SECRET, so it asks for Touch ID. `--replace` overwrites and does not read SECRET |
| `secret cookie ls --jar SECRET` | list the cookies of a jar: name, domain, flags, expiry; no values |
| `secret run --cookie-jar SECRET [--update] -- CMD` | write the jar to a temp file (mode 600), path in `$SECRET_COOKIE_JAR`, delete it after CMD; `--update` saves changes back |
| `secret mv [-f] OLD NEW` | rename with the value, comment and expiry date |
| `secret rm NAME` | delete |
| `secret run [--mask\|--no-mask] [-e FILE]... [SPEC...] -- CMD` | run CMD with secrets in its environment. SPEC is `NAME` or `VAR=NAME`. Without SPEC and `-e` it reads `./.env`. Under Claude Code (`CLAUDECODE`) the output is always masked and `--no-mask` has no effect |
| `secret check [FILE]` | for each key of a `.env`: `ok`, `MISSING` or `plain`; prints no values |
| `secret import [-p PREFIX] [-k] [FILE]` | `.env` values into the store, references into the file; `-k` keeps the file |
| `secret export [-f] [--pass-stdin] FILE` | all secrets into one encrypted file |
| `secret restore [-f] [--pass-stdin] FILE` | restore; `-f` replaces secrets that exist |
| `secret log [-n N] [NAME]` | the access log, the last N lines (default 20) |
| `secret lease [--for DURATION] NAME... \| -e FILE` | Secure Enclave store: hold the named secrets for up to 24 hours (`30m`, `6h`; default 8h) after one Touch ID that names them. They stay readable while the screen is locked or the Mac sleeps; every other name fails at once with `not leased: NAME`. Meant for an agent that works while you are away |
| `secret lease status` | the leased names and the end of each; no values, no Touch ID |
| `secret lease --revoke` | end all leases (`secret lock` ends them too) |
| `secret touchid on\|off\|status` | file keychain protected mode: only the helper reads values, after Touch ID |
| `secret touchid grace SECONDS` | how long after a confirmation not to ask again: idle seconds in the Secure Enclave store (default 1800), seconds from the confirmation in the file keychain (default 300); `0` asks every time |
| `secret touchid repair` | Secure Enclave store: rebuild its keychain item from the store file, one touch |
| `secret touchid pq` | Secure Enclave store: add an ML-KEM-768 key and seal each value with it and the P-256 key (post-quantum), one touch, macOS 26 or later |
| `secret migrate --backup FILE`, `--back` | move all secrets to the Secure Enclave store (backup to FILE first) or back to the file keychain |
| `secret version` | print the version |

VALUE as an argument shows in `ps` and in the shell history. Use stdin or `ask`.

</details>

<details>
<summary><b>Environment variables</b></summary>

| Variable | What it does |
|---|---|
| `SECRET_KEYCHAIN` | another keychain file |
| `SECRET_NO_DIALOG=1` | open no dialogs, fail instead |
| `SECRET_RUN_MASK=1` | `run` always with `--mask`; `--no-mask` cancels it for one run |
| `SECRET_LOG` | the log file (default `~/.local/state/secret/access.log`), `off` for no log |
| `SECRET_NAMES_CACHE` | the name cache for completion (default `~/.local/state/secret/names`) |
| `SECRET_LOCK_TIMEOUT` | on `init`: idle seconds before the keychain locks (default 28800) |
| `SECRET_AUTH_HELPER`, `SECRET_PBCOPY`, `SECRET_PBPASTE`, `SECRET_GH`, `SECRET_CONFIRM` | tests only: they work only with a keychain whose inode differs from the default one |

</details>

## SecretBar

<p align="center">
  <img src="docs/img/menubar-dark.png" width="300" alt="SecretBar menu">
  <img src="docs/img/quick-light.png" width="460" alt="SecretBar quick search">
</p>

```sh
./install.sh --app      # build, /Applications/SecretBar.app, launch
```

- **Quick search ⌥⌘S** from any app, in the style of Spotlight. Type a name or a word from the
  comment. ↩ copies the reference `secret:NAME`, ⇧↩ copies the value, ⌘N adds a secret, esc closes. Search understands text typed in the wrong
  keyboard layout.
- **Spotlight.** Secrets show up in Spotlight, and the action "Copy Secret" is in Shortcuts. The
  index gets only names and comments, never values. Settings → "Show in Spotlight" turns it off
  and erases the index. "Search in SecretBar" from Siri, Spotlight or Shortcuts opens the main
  window with the words in its search field. On macOS 27 Spotlight asks SecretBar to rebuild the
  index when it needs it.
- **Menu bar icon**: the lock shows the grace state: open with the time left, closed, or needs
  attention. A click opens a panel with the status and search. ↩ or a click copies the reference, ⇧↩ or ⇧-click the value. The + button adds a secret. If search finds nothing, ↩ creates a secret with that name.
- **Main window**: projects on the left (from the comment "project: …"), the list in the middle,
  the card of the secret on the right. The card shows the comment, the expiry date, the `.env`
  files that refer to `secret:NAME`, and ready lines for `secret run` and `.env`. Add, generate,
  edit, rename, delete, Activity and Settings are here too. After you add a secret, its
  reference `secret:NAME` is on the clipboard.
- **Copy** puts the value on the clipboard with the `ConcealedType` mark, so Raycast, Alfred and
  Paste do not keep it. The clipboard is cleared after 30 seconds.
- **Activity**: the latest requests (agent or you) and the Touch ID prompts from the agent log.
- **Notifications**: secrets expired or expiring within 7 days.
- **Languages**: English, German, French, Spanish, Italian, Portuguese, Polish and Russian, after the language of macOS.

The app never calls the keychain itself. All actions go through `secret` and the helper, so
Touch ID, grace and the log work as in the terminal. A value never gets into the memory of the
app: the helper puts it on the clipboard. The signature is an Apple Development certificate
without a profile, or ad-hoc. The app has no entitlements. `tests/run.sh` checks this on the
binary. `SecretBar --snapshot DIR --theme dark` renders each screen to PNG with demo data.

## References in `.env`

```sh
export API_TOKEN=secret:MYAPP_API_TOKEN     # the value is in the store
DB_PASS=secret:MYAPP_DB_PASS
PORT=8080                                   # a plain value, passed as is
```

```sh
secret import -p MYAPP_ .env    # move plain values into the store, leave references in the file
secret check .env               # ok / MISSING / plain for each key
secret run --mask -- npm start  # reads ./.env
```

The parser understands `export`, comments, `"…"` and `'…'` quotes. Multi-line values are not
supported. If a project loads `.env` with `source`, the references stay strings. Then it needs a
loader that replaces `secret:NAME` with the value after `source`, for example one that runs
`source .env` and then `secret run`.

## Security

| Threat | What `secret` does | What remains |
|---|---|---|
| A value gets into the chat of the agent | input through the `ask` dialog, generation with `gen`, output masking (always under Claude Code; the value, its base64 and URL encoding), the hook | a value inside another encoding: `base64(user:pass)` in `Authorization: Basic`, hex, a value in parts |
| A value shows in `ps` | values go to `security` through stdin, the backup password through a file descriptor | `set NAME VALUE` with the value as an argument |
| The agent reads a value around the rules | the hook stops `secret get`, `security ... -w`, `cat .env`, `env` inside `run` | a command can be written so that the hook pattern does not match it |
| A process reads secrets without the human | Secure Enclave: the key works only after `.userPresence`; the system asks Touch ID for any process with any signature; the access log | in grace the helper agent answers any process of the owner; grace is 30 idle minutes, 8 hours at most; a screen lock, sleep and `secret lock` end it; a lease (`secret lease`) is an explicit list you approved with Touch ID, up to 24 hours, and survives a screen lock and sleep: the agent can read those names while you are away |
| Replaced key item of the store | the helper reads the item only silently; a changed item is an error without a dialog; `touchid repair` restores it from the file after Touch ID | a program of the owner can replace both the item and the file with its own key; `repair` with a touch accepts it |
| Loss of the keychain or the Mac | `secret export`: AES-256-CBC, PBKDF2 600 000 iterations, sha256 inside | nobody can recover the keychain password or the backup password |
| A value stays on the clipboard | `copy` clears the clipboard after 30 seconds | clipboard managers can keep the value in their history |

**Secure Enclave store.** The helper `build/secret-vault` keeps one file. AES-GCM under the
file key encrypts the payload: names, comments, expiry dates and values. The public keys of the
Secure Enclave encrypt each value again. Thus writes need no Touch ID, and reads need Touch ID.
On macOS 26 and later each value needs two Secure Enclave keys: P-256 and ML-KEM-768
(post-quantum). Both shared secrets go into one HKDF-SHA256, then AES-GCM. A quantum computer that
breaks P-256 still cannot open a copy of the file. A new store gets both keys. An older store
keeps ECIES P-256 until you run `secret touchid pq`: one touch seals each value again.
`secret touchid status` shows `post-quantum: on`. The login keychain item `secret-cli.vault` holds the file key, the public key, the
wrapped Secure Enclave key and the grace state. Only the helper reads it without a question.

The grace lives in a helper agent process. After Touch ID it opens the values and keeps them in
memory. Its socket `~/.local/state/secret/vault-agent.sock` is open to the owner only. Hardened
runtime without `get-task-allow` closes that memory to a debugger. The Secure Enclave key is
bound to this Mac. `export` and `restore` move secrets to another Mac.

**File keychain.** Items are generic passwords with account `secret-cli`, service = the name of
the secret, kind `secret-cli`, the comment in `icmt`, the expiry date in `gena`. The keychain
locks on sleep and after 8 idle hours. When it is locked, the command asks for its password in
the terminal or in a dialog. `secret touchid on` moves all items to protected mode. The helper
`build/secret-auth` creates them again. macOS gives a value without a dialog only to the creator
of the item.

**Backup.** A file with mode 600: names, values, comments and expiry dates in hex, with sha256.
The plain text and the password go to `openssl` through a pipe and never touch the disk.
`restore` checks the password, the header and the sum before the first write. To decrypt without
`secret`: `openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -md sha256 -in FILE`.

## Agent

`./install.sh --claude-hook` connects Claude Code. A second run replaces the earlier entries.

- The hook `hooks/claude-pretooluse.sh` goes into `~/.claude/settings.json`. It looks at the
  start of each command (start of line, after `;`, `&&`, `|`, `$(`). Words in text and in commit
  messages pass, as does heredoc text for `cat`, `tee` and `git`.
- The rules `docs/claude-md-secrets.md` are imported with a line `@…/docs/claude-md-secrets.md`
  in `~/.claude/CLAUDE.md`. Claude Code reads the file at the start of a session, so the rules
  update with the command. The rules: always `run --mask`, new values through `ask` or `gen`,
  GitHub through `secret gh`, only a human changes the Touch ID settings.
- The log marks a run from Claude Code as `agent` (by the `CLAUDECODE` variable).

## FAQ

<details>
<summary>Why not 1Password or Bitwarden?</summary>

They need an account and a subscription or a cloud. `secret` runs on what macOS already has.
It is made for work with an agent: output masking, the hook, a log that marks the agent.

</details>

<details>
<summary>How do I move secrets to another Mac?</summary>

On the old Mac, run `secret export FILE`. On the new one, run
`brew install secretbar/tap/secretbar && secret init && secret restore FILE`.

</details>

<details>
<summary>Why does each <code>run</code> ask for Touch ID?</summary>

In the Secure Enclave store a question comes after 30 minutes without requests, 8 hours after
Touch ID, after a screen lock and after sleep. `secret touchid grace N` changes the idle time.
Zero asks every time. `secret touchid status` shows the time left.

An agent that works while you are away cannot get Touch ID on a locked screen. Give it a lease
before you leave: `secret lease --for 8h SHOP_DB_PASSWORD SHOP_API_KEY`. The Touch ID window
names the secrets and the term. A lease needs its own Touch ID (grace does not stand in for it)
and lasts at most 24 hours from that touch. A screen lock and sleep end the grace but keep the
lease; a secret outside it fails at once with `not leased`. `secret lease --revoke`, `secret lock`,
the end of the term, a restart or a logout end it; a changed or deleted secret leaves the lease.
`secret log` marks the reads from a lease with `lease=`.

</details>

<details>
<summary>Do I need Xcode?</summary>

Only for SecretBar. The command and the store helper need only `swiftc` from the Command Line
Tools (`xcode-select --install`).

</details>

<details>
<summary>The command says "another program changed the key item of the store"</summary>

Another program changed the key item in the keychain, or the helper was built without the earlier
certificate. The secrets are safe in the file. `secret touchid repair` creates the item again
after one touch.

</details>

<details>
<summary>Tab does not complete names</summary>

Run `secret ls` once: it builds the name cache. Then open a new terminal.

</details>

## Development

```sh
tests/run.sh    # 340+ checks on a temporary keychain and a test build of the store
```

The tests create their own keychains and delete them at the end. The real keychain, the
clipboard and the Keychain Access list do not change. A test build of the helper
(`-D SECRET_TEST`, answers from a file) checks Touch ID. It has another `cdhash` and no access to
real items. A test build `secret-vault-test` checks the Secure Enclave store with a software key
in the run directory. Dialogs and real Touch ID are checked by hand. CI runs the same suite on
macOS 15 and macOS 26 runners for each push and pull request.

**Verify a release.** Each release tarball has a build provenance attestation:
`gh attestation verify secret-X.Y.Z.tar.gz -R secretbar/secretbar`. To report a vulnerability,
see [SECURITY.md](SECURITY.md).

Each change goes through spec-kit: `specs/NNN-*/` with `spec.md`, `plan.md`, `tasks.md`. The rules
are in `.specify/memory/constitution.md`. Commits follow Conventional Commits. release-please
makes the release pull request, the tag and the changelog. Then CI updates the Homebrew formula.

```
bin/secret                     the command
helper/secret-auth.swift       Touch ID and status of the file keychain
helper/store/                  the Secure Enclave helper: main.swift, build.sh (swiftc)
app/                           SecretBar: SwiftUI, App Intents, Xcode project, build.sh
hooks/                         Claude Code hook and its installer
completions/_secret            zsh completion
docs/claude-md-secrets.md      rules for the agent
tests/run.sh                   tests
```

## License

MIT
