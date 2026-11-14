# Tasks: session-only cookies through a Safari extension and a cookie jar

**Input**: `specs/030-cookie-login-jar/spec.md` (option B)

## Stage 1 — jar infrastructure (without a GUI, testable)

- [x] T001 remove option A: `helper/login/`, the command `cmd_cookie login`, its usage, the build in `install.sh`, its tests and docs
- [x] T002 [US1] `secret cookie import --as NAME`: jar from stdin → base64 → store, `-x` and the comment `cookie jar ... via safari extension`
- [x] T003 [US2] `cmd_run --cookie-jar NAME [--update]`: temporary file 0600, `$SECRET_COOKIE_JAR`, deletion by trap, `--update` round trip, mask per cookie
- [x] T004 [US3] `cookie ls --jar NAME` (without values), `cookie pull DOMAIN --all --as NAME` (persistent cookies of the domain), `secret-cookies jar DOMAIN`
- [x] T005 [US3] hint about the extension for typical session names
- [x] T006 mask fix: skip values shorter than 4 characters (or digits ≤3), one warning on stderr
- [x] T007 hook `hooks/claude-pretooluse.sh`: block reads of `$SECRET_COOKIE_JAR` and of jar paths
- [x] T008 `tests/run.sh`: jar format, `--update` round trip, mask per cookie, short values, hook, `import` protocol
- [x] T009 README, README.ru, site, `docs/claude-md-secrets.md`: `import`, `--cookie-jar`, `pull --all`, choice between `pull` and the extension

## Stage 2a — testable core (without a GUI)

- [x] T010 [US1] loopback daemon `helper/bridge/` (swiftc): `127.0.0.1` fixed port, accepts only from loopback, `POST /jar?as=NAME` with a token → `secret cookie import` from stdin, otherwise refusal
- [x] T011 [US1] `secret cookie bridge token|start|stop`: token and port in `~/.local/state/secret/bridge.json` (0600); build of the daemon in `install.sh`
- [x] T012 [US1] web part `app/extension/`: manifest v3 (permission `cookies`), popup/JS — read `cookies.getAll` of the active domain, build a Netscape jar, POST to loopback with the token
- [x] T013 `tests/run.sh`: daemon protocol with `curl` — a correct token saves the jar, a wrong token and non-loopback are rejected
- [x] T014 README, README.ru, site, `docs/claude-md-secrets.md`: daemon, `bridge token`, install of the extension, per-site access, token pairing

## Stage 2b — Xcode wrapper of the extension (manual build)

- [x] T015 Xcode app of the extension with `xcrun safari-web-extension-converter app/extension`, signature, build in `app/`
- [x] T016 2026-11-11 `ru` translations of the extension strings: `_locales/en|ru/messages.json`, `i18n.js`, key checks in `tests/run.sh`. The look in Safari with a Russian system language is not checked by hand

## Manual checks

- [x] T017 manual, 2026-11-04: the extension is on, the token is paired, on portal.example.org the button saved a jar of 13 cookies, the session-only `ASP.NET_SessionId` included
- [x] T018 manual, 2026-11-04: `run --cookie-jar TAX_SESSION --update` — curl sends `ASP.NET_SessionId` and is authorized: `/app/Notifications` gives 200 (the MainPage.aspx 302 goes to the account, not to Login)
- [x] T019, 2026-11-04: the junk secrets `TAX_USER_TOKEN`, `TAX_COOKIE_COMMITSTATUS`, `TAX_COOKIE_ISEMP` were deleted (with the owner's confirmation)
