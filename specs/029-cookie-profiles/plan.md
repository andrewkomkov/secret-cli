# Implementation Plan: cookies from all Safari profiles

**Spec**: `specs/029-cookie-profiles/spec.md`

The detailed design with code is in the owner's bug report (pasted into the feature history).
Here is the essence.

## Technical Context

### helper/cookies/main.swift

- The path is replaced by a directory: `SECRET_TEST_SAFARI` (test) or
  `.../com.apple.Safari/Data/Library` (release).
- `struct Store { profile; path }`. `stores()` gives `default` (`Cookies/Cookies.binarycookies`)
  and one per each subdirectory `WebKit/WebsiteDataStore/<UUID>` (`.../Cookies/Cookies.binarycookies`).
  No directory `WebsiteDataStore` — only the default. No permission on the directory — code 77.
- `load(_ Store)` opens the file: `ENOENT` → empty (a profile without cookies),
  `EPERM`/`EACCES` → 77, broken file → 65. It sets the profile on each cookie.
- `Cookie` gets the field `profile`. `parse` does not change.
- `pick(cs, domain, name, path)` chooses one cookie: several paths or domains → code 3 (as
  before); otherwise the cookie with the latest date (`expiry`), which is the newest login.
- Parse of `--profile ID` at the start of argv. Commands: `list` (profile column), `value`, new
  `which` (`profile<TAB>expiry`), `path` (`profile<TAB>file` per line).

### bin/secret

- `cookies_run`: the message for 77 no longer calls `path` a second time (there are several
  files).
- `cmd_cookie ls`: flag `--profile`, column `PROFILE` in the table.
- `cmd_cookie pull`: flag `--profile`. First `which` → `profile` and `expiry`, then
  `value --profile "$profile"` — the value and the date come from one cookie. Comment:
  `safari cookie DOMAIN NAME, profile PROFILE`.
- usage: `ls [--profile ID] DOMAIN`, `pull ... [--profile ID]`, "several profiles — the
  latest".

### Tests (tests/run.sh)

The test build reads `SECRET_TEST_SAFARI` instead of `SECRET_TEST_COOKIES`. The fixture is a
directory with `Cookies/Cookies.binarycookies` and
`WebKit/WebsiteDataStore/<UUID>/Cookies/Cookies.binarycookies`.
Cases 1–10 from the bug report: a cookie only in a profile; the same cookie with different dates
(the later one wins, `-x` from it); `--profile default`; unknown `--profile` (code 1); no
`WebsiteDataStore`; a profile without a file; a broken profile file (65); two paths in two
profiles (code 3); `path` with `default` and UUID; no value in `which`/`path`/comment.

## Constitution Check

- **I**: only `value` gives the cookie value, through a pipe into the store record. `list`,
  `which`, `path` and the comment do not print the value.
- **III**: the helper is the same — Swift from source in the repo, without network.
- **IV**: `tests/run.sh` on a fixture directory, without Safari and Full Disk Access. The check on
  a real multi-profile Safari is manual, with a date in `tasks.md`.
- **V**: `secret cookie` is the same command; the flag `--profile` and the column `PROFILE` are
  added. The `.binarycookies` format and the other commands do not change.

## Complexity Tracking

| Deviation | Reason |
|---|---|
| `value` and `which` as two calls | The value must not go next to the metadata. `which` gives the profile and the date without the value, then `value --profile` takes the value from the same profile. |
