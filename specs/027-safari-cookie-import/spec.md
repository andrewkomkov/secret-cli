# Feature Specification: import of cookies from Safari into the store

**Feature Branch**: `027-safari-cookie-import`. The work goes on in `main`.

**Created**: 2026-11-03

**Status**: Draft 2026-11-03

**Input**: Owner: "so that the app can look into Safari cookies". The owner is tired of opening
the debug mode by hand and copying cookies from Storage. An agent acting as the owner must do
actions on sites without an API and a token. An example is an SSO proxy in front of Grafana. For
this, the feature moves a session cookie from Safari into the store once.

## Context and scope

- The feature reads **persistent cookies** from the Safari file
  `~/Library/Containers/com.apple.Safari/Data/Library/Cookies/Cookies.binarycookies`.
- Safari does not write pure in-memory cookies (no date, "until the tab is closed") to the
  file. The feature skips such a cookie. This is a known limit of the format.
- `sessionStorage` and `localStorage` are not cookies. They are not in this file. They are out
  of the scope of the feature.
- The feature works only with Safari. Chrome and Firefox are for the future. Chrome encrypts the
  values with a key from the keychain; that is separate work.
- TCC protects the file. The reader of the file (Terminal for the CLI, later SecretBar.app)
  needs **Full Disk Access**. Without access, the command fails with a clear error.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - list of cookies by domain (Priority: P1)

1. **When** a person runs `secret cookie ls <domain>`, **Then** the command prints the cookie
   names of this domain. Next to them: the flags `Secure` and `HTTPOnly`, the path and the expiry
   date. The command keeps the values secret.
2. **When** the domain is empty, **Then** the command prints an empty list and exits with code 0.
3. **When** Full Disk Access is missing, **Then** the command names the cause and the file path,
   explains how to give access and opens the needed Settings pane.

### User Story 2 - import of a cookie into the store (Priority: P1)

1. **When** a person runs `secret cookie pull <domain> <name> --as NAME`, **Then** the helper
   passes the cookie value into the store record named `NAME`. The value is not in argv or
   logs.
2. **When** the cookie has an expiry date, **Then** the command sets `-x` with this date on the
   secret. Then `secret ls --expiring` warns about the expiry in advance.
3. **When** several cookies with one name and different paths match the domain, **Then** the
   command asks for the flag `--path` and prints the list of paths. The command keeps the values
   secret.
4. **When** the cookie is missing, **Then** the command gives an error and code 1. The store
   stays unchanged.
5. The secret comment keeps the domain and the cookie name. The value does not go into the
   comment.

## Requirements *(mandatory)*

- **FR-001**: new command `secret cookie` with the subcommands `ls` and `pull`. The old commands
  and flags stay as they are.
- **FR-002**: the `.binarycookies` reader is the Swift helper `helper/cookies/`. The source is in
  the repo. The build uses `swiftc` from the Command Line Tools. The signature is the same as for
  the store helper. Without a built helper, `secret cookie` reports that the feature is not
  available.
- **FR-003**: the helper gives the value of the chosen cookie to stdout. `bin/secret` pipes it
  into the store record. The `ls` mode prints only names and metadata.
- **FR-004**: Full Disk Access gate. On `EPERM` and `EACCES`, the command prints the path and a
  hint, then opens the `Privacy_AllFiles` pane.
- **FR-005**: the command sets `-x` from the cookie expiry date. The comment keeps the domain and
  the cookie name.
- **FR-006**: the flag `--as NAME` of `pull` is required. The name goes through the same check as
  in `set`.

## Success Criteria *(mandatory)*

- **SC-001**: one command puts a session cookie (of the Grafana or SSO proxy type) into the
  store. There is no need to open the Web Inspector.
- **SC-002**: the cookie value stays out of the `ls` stdout, out of the process argv and out of
  the logs.
- **SC-003**: for an imported cookie with an expiry date, `secret ls --expiring` shows it in
  advance.
- **SC-004**: without Full Disk Access, the command gives a clear instruction.
