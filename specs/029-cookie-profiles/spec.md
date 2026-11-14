# Feature Specification: cookies from all Safari profiles

**Feature Branch**: `029-cookie-profiles`. The work goes on in `main`.

**Created**: 2026-11-03

**Status**: Draft 2026-11-03

**Input**: Owner's bug report: `secret cookie ls`/`pull` read only the default profile
(`Library/Cookies/Cookies.binarycookies`). The cookies of each other profile are in
`Library/WebKit/WebsiteDataStore/<UUID>/Cookies/Cookies.binarycookies`. A login to a site in
another profile, and the command does not find the cookie.

## Context and scope

- Safari keeps the default profile in `Cookies/`, and each other profile in
  `WebsiteDataStore/<UUID>/`.
- An empty or missing profile file is skipped; this is not an error.
- The feature changes only the helper `secret-cookies` and the command `secret cookie`. The
  `.binarycookies` format, the parsing and the other commands do not change.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - ls sees all profiles (Priority: P1)

1. **When** a person runs `secret cookie ls DOMAIN`, **Then** the command prints the cookies of
   this domain from the default and all profiles. A new column `PROFILE` names the profile
   (`default` or UUID).
2. **When** a profile has no cookie file, **Then** the command skips it and the exit code is 0.
3. **When** `--profile ID` is given, **Then** the command reads only this profile. An unknown ID
   gives code 1 and the message `no Safari profile`.

### User Story 2 - pull takes the correct cookie (Priority: P1)

1. **When** the same cookie is in several profiles, **Then** `pull` takes the cookie with the
   latest expiry date (this is the newest login). The date and the comment of the secret come
   from the same cookie.
2. **When** a name has several paths or several domains, **Then** this is an error (code 3), as
   before.
3. **When** `--profile ID` is given, **Then** `pull` takes the cookie of this profile.
4. The secret comment contains the domain, the cookie name and the profile.

## Requirements *(mandatory)*

- **FR-001**: `secret-cookies` reads the default file and each
  `WebsiteDataStore/*/Cookies/Cookies.binarycookies`. No file — the profile is skipped.
- **FR-002**: each cookie has a profile (`default` or UUID). `list` prints it as a column.
- **FR-003**: the flag `--profile ID` of `ls` and `pull` reads one profile.
- **FR-004**: new helper command `which DOMAIN NAME [PATH]` prints `profile<TAB>expiry` of the
  chosen cookie. `pull` calls `which`, then `value --profile`, so that the date and the value come
  from one cookie.
- **FR-005**: with the same cookie in several profiles, `value`/`which` take the latest date.
  Several paths or domains for a name is an error (code 3).
- **FR-006**: `secret-cookies path` prints `profile<TAB>file` for each file.
- **FR-007**: the cookie value is not printed in `list`, `which`, `path` or the comment. Only
  `value` gives the value.
- **FR-008**: the test build reads the directory from `SECRET_TEST_SAFARI` instead of the real
  Safari.

## Success Criteria *(mandatory)*

- **SC-001**: a cookie that is only in a profile is visible in `ls` with the UUID, and `pull`
  stores its value in the store.
- **SC-002**: with the same cookie in two profiles, `pull` without `--profile` takes the value
  with the later date and sets it in `-x`.
- **SC-003**: a missing `WebsiteDataStore` directory gives the same result as in 1.3.0.
- **SC-004**: the cookie value stays out of `list`, `which`, `path` and the comment.
