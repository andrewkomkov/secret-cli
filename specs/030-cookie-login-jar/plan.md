# Implementation Plan: session-only cookies through a Safari extension and a cookie jar

**Spec**: `specs/030-cookie-login-jar/spec.md` (option B — Safari extension)

## Stages

- **Stage 1 — jar infrastructure (without the extension).** Common plumbing that works by itself
  and is tested without a GUI. This is the base that the extension stands on.
- **Stage 2 — Safari extension + bridge.** Capture of the live session and delivery of the jar
  into the store.

Option A (a WKWebView window, `cookie login`, `helper/login`) is rejected and is removed from the
tree.

## Stage 1: jar infrastructure

### Storage and format
- Netscape cookie jar (HttpOnly with the prefix `#HttpOnly_`). In the secret: base64 (the value
  is one line). The comment and `-x` are computed from the jar (the minimum expiry of the
  persistent cookies; all session-only → no `-x`, `session` in the comment).

### `bin/secret`
- `secret cookie import --as NAME`: reads the jar from stdin, encodes it in base64, writes it
  through the `cmd_set` path (value through a pipe, not argv), sets `-x` and the comment.
- `secret run --cookie-jar NAME [--update]`: the jar goes to a `mktemp` file 0600, the path to
  `$SECRET_COOKIE_JAR`; a `trap` on EXIT/HUP/INT/TERM deletes the file; `--update` saves the
  changed jar. The mask covers each cookie.
- `secret cookie ls --jar NAME`: metadata without values.
- `secret cookie pull DOMAIN --all --as NAME`: the persistent cookies of the domain from
  `secret-cookies jar DOMAIN` (all profiles, 029) into one jar.
- A hint about the extension for typical session names.
- Mask fix FR-012: skip values shorter than 4 characters (or digits ≤3), one warning on stderr.

### Hook
- `hooks/claude-pretooluse.sh` blocks reads of `$SECRET_COOKIE_JAR` and of jar file paths.

### What to remove from the tree (option A)
- `helper/login/` (the WKWebView helper), the command `cmd_cookie login`, its usage, its build in
  `install.sh`, its tests and mentions in the docs. Keep the rest of the agent's work.

## Stage 2: Safari extension + loopback daemon

A change against the first draft: the bridge is a separate swiftc daemon, not a server inside
SecretBar. So the core is tested over HTTP without a GUI, and the working Xcode project of
SecretBar is not touched.

### Loopback daemon (`helper/bridge/`, swiftc)
- `secret-bridge`: listens on `127.0.0.1` on a fixed port, accepts only from loopback.
- `POST /jar?as=NAME` with the header `X-Secret-Token`: with a correct token, it reads the body
  (Netscape jar) and calls `secret cookie import --as NAME` through stdin. Otherwise 401/403, it
  saves nothing.
- The token and the port are in `~/.local/state/secret/bridge.json` (0600). `secret cookie bridge
  token` prints the token to paste into the extension; `secret cookie bridge start|stop` controls
  the daemon.
- Tested in `tests/run.sh` with plain `curl` on loopback: a correct token saves the jar, a wrong
  one is refused, non-loopback is refused.

### Safari extension (web part + Xcode wrapper)
- `app/extension/`: manifest v3, the permission `cookies` and host access, popup. The button
  reads `browser.cookies.getAll` of the active domain (HttpOnly and session), builds a Netscape
  jar, sends `POST http://127.0.0.1:PORT/jar?as=NAME` with the token from the extension settings.
- The Xcode app wrapper is made with `xcrun safari-web-extension-converter app/extension` (a
  separate step with a build). Apple Development or ad-hoc signature; without it, "Allow Unsigned
  Extensions" in the Safari Develop menu.

### Manual steps (person)
- Turn on the extension in Safari, give cookie access per site, paste the token from `secret
  cookie bridge token` into the extension settings once.

### Manual steps (person)
- Turn on the extension in Safari, give cookie access per site, paste the token from SecretBar
  into the extension settings once.

## Constitution Check

- **I**: cookie values do not go to the stdout of normal commands, to argv or to logs. The jar
  from the extension goes over loopback to SecretBar, then to `import` through stdin. `ls --jar`
  prints only metadata. The temporary jar file is 0600, it is deleted, and the hook blocks reads.
- **II**: `import` writes a secret — confirmation as with `set`. `run --cookie-jar` reads a
  secret — Touch ID in one request. The person logged in to the site earlier in their own Safari.
- **III**: the extension and the server are part of SecretBar (Xcode, Apple Development or ad-hoc
  signature, without a profile and entitlements). `secret` and the helpers are as before. Without
  SecretBar/the extension the delivery does not work; the other commands work.
- **IV**: `tests/run.sh` checks stage 1 without a GUI: jar format, `--update` round trip, mask,
  short values, hook, `import` protocol. The live extension and loopback are a manual check with a
  date.
- **V**: new commands `cookie import`, `cookie ls --jar`, `cookie pull --all`, flags `run
  --cookie-jar`/`--update`. The existing commands and the `secret:NAME` format do not change.

## Complexity Tracking

| Deviation | Reason |
|---|---|
| Safari extension + loopback bridge in SecretBar | Only code inside Safari reads session/HttpOnly cookies. App groups are closed by the rule "no entitlements", so the bridge goes over loopback, not through the helper sandbox. |
| The jar as one secret in base64 | The store keeps one-line values, and a jar has many lines. |
| `run --update` writes the secret after `cmd` | ASP.NET rotates the session. Without a save, it dies in ~20 minutes. |
| The mask skips short values | `isEmp=0` broke `302` into `3***2`. |
