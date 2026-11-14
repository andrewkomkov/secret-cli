# Feature Specification: session-only cookies through a Safari extension and a cookie jar

**Feature Branch**: `030-cookie-login-jar`. The work goes on in `main`.

**Created**: 2026-11-04

**Status**: Draft 2026-11-04 (option B — Safari extension; option A with a WKWebView window is rejected)

**Input**: Request from a neighbouring session (case of 2026-11-04): the portal.example.org
account (ASP.NET WebForms) keeps the session in `ASP.NET_SessionId`, an HttpOnly session cookie
without an expiry. Safari does not write it to `Cookies.binarycookies`, and it cannot be read
through `document.cookie` (HttpOnly). `secret cookie pull` takes only persistent cookies, and a
request to `MainPage.aspx` gives 302 to `Login.aspx`. The owner chose B: read the cookies from
the **real** Safari session, without a second window and without a second login.

## Goal

The agent gets a working site session from a tab that is already open in Safari: without a login
in the chat, without a password, without showing values. The person did the login, the password
and the SMS earlier in their own Safari.

## Context and scope

- Session-only and HttpOnly cookies live in the Safari memory. Only code inside Safari reads
  them. This is a Safari extension with the permission `cookies`.
- The repository rule "no paid account and no entitlements" closes app groups. So
  `SafariWebExtensionHandler` cannot write from the sandbox into the store. The bridge goes over
  loopback: **extension → 127.0.0.1 (SecretBar server) → SecretBar → `secret cookie import`**.
- A person does the manual steps: turns on the extension in Safari, gives cookie access per
  site, pastes the pairing token from SecretBar into the extension settings once.
- Reused from the common infrastructure: the jar format, the storage of the jar in a secret
  (base64), `secret run --cookie-jar`, the mask per cookie, the hook on the jar file,
  `cookie ls --jar`, `cookie pull --all`.
- Out of scope: Chrome and Arc (the values are encrypted with Chrome Safe Storage), going around
  a captcha and 2FA (a person always passes them).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - capture of the session from Safari (Priority: P1)

1. **When** a person on the needed Safari tab clicks the extension button, **Then** the extension
   reads the cookies of the tab domain (HttpOnly and session included), builds a Netscape jar and
   sends it to the SecretBar loopback with the pairing token.
2. **When** SecretBar accepted the jar with a correct token, **Then** it calls `secret cookie
   import --as NAME` and saves the jar as one secret (base64). The name comes from the extension
   request.
3. **When** the token is wrong or the request is not from loopback, **Then** SecretBar rejects
   the request and does not save the cookies.
4. The values go neither to stdout nor to the log. `secret log` records the write. The write
   requires confirmation, as `set` does.

### User Story 2 - run of a command with a jar (Priority: P1)

1. **When** a person runs `secret run --cookie-jar NAME -- cmd`, **Then** the command writes the
   jar to a temporary file 0600, and the path goes to `$SECRET_COOKIE_JAR`. Example:
   `curl -b "$SECRET_COOKIE_JAR" -c "$SECRET_COOKIE_JAR"`.
2. **When** `cmd` has finished, **Then** the command deletes the file, also by a trap on signals.
3. **When** `--update` is given, **Then** after `cmd` the command saves the changed jar back into
   the secret.
4. The mask covers the value of each cookie from the jar. Confirmation of the names is one Touch
   ID request.

### User Story 3 - inspection and persistent cookies (Priority: P2)

1. **When** a person runs `secret cookie ls --jar NAME`, **Then** the command prints the names,
   domains, flags and expiry of the cookies inside the jar, without values.
2. **When** a person runs `secret cookie pull DOMAIN --all --as NAME`, **Then** the command
   collects the persistent cookies of the domain from the Safari files (all profiles, 029) into
   one jar. This is the path when the session is persistent after all.
3. **When** `pull` or `import` see typical session names (`ASP.NET_SessionId`, `.ASPXAUTH`,
   `JSESSIONID`, `PHPSESSID`) and they are not on disk, **Then** the command prints a hint about
   the extension.

## Requirements *(mandatory)*

- **FR-001**: a Safari extension (Web Extension) with the permission `cookies` reads the cookies
  of the active domain and builds a Netscape jar. An Xcode target as part of SecretBar. The
  signature is the same as for SecretBar.
- **FR-002**: SecretBar keeps a loopback server on `127.0.0.1` with a random port and a pairing
  token. It accepts a jar only with a correct token and only from loopback. The person takes the
  token in SecretBar and pastes it into the extension settings.
- **FR-003**: `secret cookie import --as NAME` reads a jar from stdin, encodes it in base64 and
  saves it as a secret. SecretBar calls it. Comment `cookie jar DOMAIN via safari extension, N
  cookies, session-only: a,b`. The expiry is the minimum expiry among the persistent cookies; all
  session-only → no expiry, `session` in the comment.
- **FR-004**: the jar format is the Netscape cookie jar (as in curl, HttpOnly with the prefix
  `#HttpOnly_`).
- **FR-005**: in the secret, the jar is in base64 (the value is one line).
- **FR-006**: `secret run --cookie-jar NAME [--update]` writes the jar to a temporary file 0600,
  the path to `$SECRET_COOKIE_JAR`, deletes the file after `cmd` and by a trap; `--update` saves
  the changed jar.
- **FR-007**: the mask covers the value of each cookie from the jar separately.
- **FR-008**: `secret cookie ls --jar NAME` prints the cookie metadata without values.
- **FR-009**: `secret cookie pull DOMAIN --all --as NAME` collects the persistent cookies of the
  domain into a jar.
- **FR-010**: a hint about the extension for typical session names without a file on disk.
- **FR-011**: the hook `hooks/claude-pretooluse.sh` blocks reads of `$SECRET_COOKIE_JAR` and of
  jar file paths with the commands `cat`/`head`/`tail`/`less`/`cp` inside `secret run`.

### Related fix of the mask for short values

- **FR-012**: `--mask` does not mask values shorter than 4 characters (or only digits with a
  length ≤3). It prints `mask skipped for short value NAME` to stderr once. The reason: `isEmp=0`
  turned `302` from `curl -w "%{http_code}"` into `3***2`.

## Success Criteria *(mandatory)*

- **SC-001**: on the portal.example.org tab, the extension button saves a jar with
  `ASP.NET_SessionId` through SecretBar and `secret cookie import`.
- **SC-002**: `secret run --mask --cookie-jar TAX_SESSION --update -- curl -s -o /dev/null -w
  '%{http_code}' -b "$SECRET_COOKIE_JAR" -c "$SECRET_COOKIE_JAR"
  https://portal.example.org/MainPage.aspx` gives `200`, not 302.
- **SC-003**: no command prints values. The tests cover the jar format, the `--update` round
  trip, the mask per cookie, the short value rule, the hook and the `import` protocol (without a
  live extension).
- **SC-004**: `docs/claude-md-secrets.md`, section "How to import a browser session", describes
  the extension, `import`, `--cookie-jar` and the choice between `pull` and the extension.
