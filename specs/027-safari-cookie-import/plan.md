# Implementation Plan: import of cookies from Safari into the store

**Spec**: `specs/027-safari-cookie-import/spec.md`

## Technical Context

### Format of `Cookies.binarycookies`

- Path: `~/Library/Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies`.
- Header: magic `cook`, then `uint32 BE` — the number of pages, then the page sizes (`uint32 BE`).
- Page: tag `0x00000100`, `uint32 LE` — the number of cookies, cookie offsets (`uint32 LE`), footer.
- Cookie record: size, flags (`uint32 LE`: bit 0 — `Secure`, bit 4 — `HTTPOnly`), field offsets
  (domain, name, path, value), two dates `float64 LE`. A date is Mac epoch, offset `978307200`
  seconds from Unix epoch.
- Field strings are C strings with a terminating zero at their offsets.

### Helper `helper/cookies/`

- `helper/cookies/main.swift` is the reader. It parses the file and filters by domain.
- Helper subcommands:
  - `list DOMAIN` — prints one line per cookie: `name<TAB>path<TAB>flags<TAB>expiry`. No value.
  - `value DOMAIN NAME [PATH]` — prints to stdout only the value of one cookie. Several
    matches without `PATH` → an error with the list of paths, no value.
- `helper/cookies/build.sh Release|Test OUTDIR` — a mirror of `helper/store/build.sh`: `swiftc -O`,
  Apple Development or ad-hoc signature, hardened runtime, record `*.src-sha256`.
- Test build `-D SECRET_TEST`: the reader takes the file path from `SECRET_TEST_COOKIES`, not
  from Safari. So `tests/run.sh` reads a synthetic `.binarycookies` without Safari and without
  Full Disk Access.

### Full Disk Access gate

- The reader opens the file. On `EPERM`/`EACCES` it exits with code `77` (`EX_NOPERM`).
- `bin/secret` catches code `77`: it prints the path, explains Full Disk Access and calls
  `open "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"`.

### `bin/secret`

- New `cmd_cookie` and the branch `cookie)` in the dispatcher next to the others.
- `secret cookie ls DOMAIN` → helper `list`, table output.
- `secret cookie pull DOMAIN NAME --as SECRET [--path PATH]`:
  1. the helper `value DOMAIN NAME [PATH]` gives the value to stdout;
  2. `bin/secret` pipes it into the same store record as `cmd_set`, without argv;
  3. it sets the expiry date from `list` with the flag `-x`;
  4. the comment is `safari cookie DOMAIN NAME`.
- `install.sh` builds the cookies helper next to the store helper. Without `swiftc`, the command
  reports that the feature is not available; the other commands work.

## Constitution Check

- **I**: `ls` prints only names and metadata. The cookie value goes from the helper to stdout
  and through a pipe into the store record. The value is not in argv or logs. There is no new
  command that prints a value.
- **II**: the write to the store goes without Touch ID, as with `set`. A later read of the
  secret asks for Touch ID. A person gives Full Disk Access in Settings; the command does not go
  around it.
- **III**: the reader is a Swift helper from source in the repo, built with `swiftc` from the
  Command Line Tools, without network and Homebrew. Without a built helper, the command reports
  that it is not available.
- **IV**: `tests/run.sh` parses a synthetic `.binarycookies` from `SECRET_TEST_COOKIES`. It checks
  the list of names and the extraction of a value. Safari, the real file and Full Disk Access
  are a manual check with a date in `tasks.md`.
- **V**: `secret cookie` is a new command. The old commands, the `secret:NAME` format, the
  account and the keychain path stay as they are.

## Complexity Tracking

| Deviation | Reason |
|---|---|
| New compiled helper `helper/cookies/` | Parsing the Safari binary format is more type-safe and easier to test in Swift than in bash. Full Disk Access is given to one signed binary only. SecretBar reuses the same helper. |
| Read of a file of another app (Safari) | The only way to get a persistent `HTTPOnly` cookie without manual steps. The file belongs to the owner, and the owner gives access through Full Disk Access. |
