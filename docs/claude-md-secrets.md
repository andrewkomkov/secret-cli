# Secrets

## Where secrets are

All passwords, tokens and API keys are in the Secure Enclave store
(`~/.local/share/secret/vault`, its key in the login keychain). Before `secret migrate`, they are
in the custom keychain `secrets` (`~/Library/Keychains/secrets.keychain-db`).
`secret touchid status` shows the store. Use the
`secret` command (`~/.local/bin/secret`) for all work with them. Run `secret help` for the full
usage.

The source of `secret` is the repository `github.com/andrewkomkov/secret-cli`. With Homebrew,
`secret` is in `$(brew --prefix secret)/libexec`. From a clone, `~/.local/bin/secret` is a symlink
to `bin/secret` in the clone. Make changes to the command in that repository, run
`tests/run.sh` there and commit. `~/.claude/CLAUDE.md` imports this file
(`docs/claude-md-secrets.md`) with an `@` line, so a change here goes to every session.

- Each item has account `secret-cli` and a name (service) in UPPER_SNAKE_CASE.
- Names of project secrets start with the project prefix, for example `SHOP_DB_PASSWORD`
  for the project `shop`.
- Each item has a comment that tells what the secret is and where it is used.

To find a secret, run `secret ls -l`. It shows the names and the comments, not the values. Then
use the name. Do NOT guess a name.

## How to use a secret

- In a command: `secret run --mask NAME -- cmd` or `secret run --mask VAR=NAME -- cmd`. The value
  goes only into the environment of `cmd`. `--mask` replaces the value with `***` in the output of
  `cmd`. Under Claude Code the mask is always on, and `--no-mask` does not work. Write `--mask`
  anyway, so that the command is clear. The mask also catches base64 and URL encoding of a value,
  but not other encodings, for example `base64(user:pass)`.
- In a project `.env`, write a reference instead of the value: `GITHUB_TOKEN=secret:GITHUB_TOKEN`.
  Run with `secret run -- cmd` (reads `./.env`) or `secret run -e FILE -- cmd`.
- If the project has `ops/lib/load_env.sh`, load `.env` with `. ops/lib/load_env.sh .env`. Do
  NOT use `source .env` there: the references stay unresolved.
- To check a `.env`, run `secret check FILE`. It shows `ok`, `MISSING` or `plain` for each key
  and prints no values.
- To check that one secret exists, run `secret has NAME`.

## How to add or change a secret

- If the keychain does not have the secret, run `secret ask NAME "<what to paste and where to get it>"`. It opens a
  macOS dialog with hidden input. The user types the value there, so the value does not go into
  the conversation. Do NOT ask the user to paste a value into the chat.
- If a new password or key is necessary (for example, for a new database user), run
  `secret gen -c "<comment>" NAME`. It makes a random value and does not show it. Options:
  `-l LEN`, `-s alnum|symbols|hex`.
- If you already have the value, pipe it: `printf '%s' "$VALUE" | secret set -c "<comment>" NAME`.
  Do NOT give the value as an argument.
- Always give a comment for a new secret: the project, what the secret is, and where it is used.
  To change a comment, run `secret note NAME "<comment>"`.
- If a token has an expiry date, store it with `-x YYYY-MM-DD` or run
  `secret expire NAME YYYY-MM-DD`. `secret ls --expiring` shows the secrets that expire soon. If
  `run` shows `warning: NAME expired`, tell the user.
- Do NOT run `secret export` or `secret restore` unless the user asks. The user types the backup
  password in the dialog. Do NOT use `--pass-stdin` with a password that you know.
- To rename a secret, run `secret mv OLD NEW`. Then change each reference `secret:OLD` in the
  `.env` files.
- To move a plain `.env` into the keychain, run `secret import -p PROJECT_ FILE`. With `-k`, the
  command stores the values and does not change the file.

## How to put a secret into GitHub Actions

- Run `secret gh NAME [GH_NAME] -R OWNER/REPO`. Add `-e ENV` for an environment, or
  `-o ORG -v private|all|selected` for an organization. The value goes to `gh secret set` on stdin.
- The user confirms each push in a macOS dialog. Wait for it. If the user cancels, stop and ask
  why. Send a secret only to a repository that the user named.
- GitHub does not give the value back. To check a push, run `gh secret list -R OWNER/REPO`: it
  shows the names and the dates.

## How to import a browser session

- To act on a site without an API as the user, do NOT ask for the cookie value. Run
  `secret cookie ls DOMAIN` to see the names and the profile of each cookie, then
  `secret cookie pull DOMAIN NAME --as PROJECT_NAME` to store the cookie. Use it later with
  `secret run --mask`.
- `ls` shows no values. `pull` gives the secret the comment `safari cookie DOMAIN NAME, profile PROFILE`
  and the expiry date of the cookie. If several paths match, add `--path PATH`. All Safari profiles
  are read; with the same cookie in several profiles, `pull` takes the one that expires last. To
  read one profile, add `--profile ID` (`default` or the ID from the `PROFILE` column).
- The command needs Full Disk Access for the terminal app. If it opens the settings pane, tell the
  user and wait. Do NOT try to go around it. Only persistent Safari cookies are in the file: an
  in-memory cookie is not there.
- Choose by the cookie. A persistent cookie (it has an expiry date in `secret cookie ls`): use
  `pull`; `pull DOMAIN --all --as PROJECT_NAME` stores all persistent cookies of the domain as one
  jar. A session cookie (HttpOnly, no expiry, for example `ASP.NET_SessionId`, `JSESSIONID`,
  `PHPSESSID`): Safari does not write it to disk. The Safari extension reads it from the
  user's real session and posts the jar to the loopback daemon (`secret cookie bridge start`; the
  user pastes the token from `secret cookie bridge token` into the extension once), which calls
  `secret cookie import --as PROJECT_NAME` with the jar on stdin. Do NOT print the bridge token
  into the chat or files. The user logs in in Safari. Do NOT ask for the login, the password or the SMS in
  the chat. If `pull` or `ls` prints `session cookie not on disk: capture it with the Safari
  extension`, ask the user to capture the session.
- A jar is one secret (Netscape format, base64). `secret cookie ls --jar NAME` shows names, domains,
  flags and expiry, no values. Use it with
  `secret run --mask --cookie-jar NAME --update -- sh -c 'curl -b "$SECRET_COOKIE_JAR" -c "$SECRET_COOKIE_JAR" URL'`.
  Wrap it in `sh -c '...'`: `$SECRET_COOKIE_JAR` must be expanded by the command, not by the shell that starts `secret run`.
  The jar goes to a temp file (mode 600) that is deleted after the command; `--update` saves new
  cookies back. Do NOT read `$SECRET_COOKIE_JAR` with `cat`, `cp` and the like: the hook stops it.

## Rules

- Do NOT run `secret get`. Do NOT print, echo or log a value. Exception: the user asks for it.
- Do NOT write a value into files, `.env`, configs, commits, docs or memory. Write the name of the
  secret.
- When you check a value, compare it inside `secret run`, for example
  `secret run --mask NAME -- sh -c '[ "$NAME" = "$OTHER" ] && echo ok || echo diff'`.
- A PreToolUse hook (`hooks/claude-pretooluse.sh` in the repository) stops commands that show
  values: `secret get`, `security find-generic-password -w` or `-g`, `security dump-keychain -d`,
  `cat .env`, and `env`, `printenv` or `set` inside `secret run`. Do NOT try to go around the hook.
  If the user wants to see a value, ask the user to run `! secret get NAME`. If the user wants to
  paste a value somewhere, suggest `! secret copy NAME` or SecretBar (⌥⌘S).
- Do NOT run `secret copy`, and do NOT run SecretBar actions through `shortcuts`. You can read
  the clipboard, so `secret copy` is for the user only. Under Claude Code it fails.
- `secret log` shows which secrets were read, when, and by whom (`agent` or `human`).
- If the keychain is locked, the command opens a password dialog for the user. Wait for it. Do NOT
  try to go around it.
- If Touch ID is on (`secret touchid status`), only the helper reads the values: `get`, `copy`,
  `run`, `export` and `mv` ask the user for Touch ID. One `run` with all the names asks once. Wait
  for it. If the user refuses, stop and ask why. Only the user changes the Touch ID settings:
  - Do NOT run `secret touchid off`, `secret touchid grace` or `secret touchid repair`.
  - Do NOT change `~/.local/state/secret/touchid-ok`.
- In the Secure Enclave store, Touch ID is always on. `ls`, `has`, `check`, `note` and
  `expire` do not ask for it.
  After a confirmation, the next question comes after 30 minutes without requests or after
  8 hours. A locked screen, a sleep of the Mac and `secret lock` end the grace time. Do NOT run
  `secret lock` without a reason: the user then confirms again.
- Do NOT run `secret migrate` unless the user asks. It moves all secrets to another store.
- If a command shows `another program changed the key item of the store`, tell the user. The
  user runs `! secret touchid repair`.
- Do NOT read values with `security`, `build/secret-auth` or `build/secret-vault` directly. Do NOT change the files in `~/.local/share/secret/`. If a
  command shows the error `not protected: NAME`, another app replaced the item: tell the user.
