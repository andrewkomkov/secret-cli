# Feature Specification: cookie import merges the jar instead of overwriting it

**Feature Branch**: `031-cookie-jar-merge`. The work goes on in `main`.

**Created**: 2026-11-04

**Status**: Draft 2026-11-04

**Input**: Owner: "TAX_SESSION now keeps only the tax.example.org cookies — on save, the
extension replaced the portal cookies in it. I want the extension to keep everything and
overwrite nothing".

## Goal

A capture from a new domain into the same secret **adds** its cookies and updates its own, but
keeps the cookies of other domains. One secret collects the sessions of several sites.

## Context and scope

- `secret cookie import --as NAME` now overwrites the whole secret. This is the cause of the loss.
- The merge goes by the key `(domain, path, name)`. A cookie with the same key is taken from the
  new jar (fresh); the cookies of other keys from the old secret are kept.
- The merge reads the old secret, so `import` in this case asks for Touch ID (as any read).
- Only `cookie import` changes. The other commands and the jar format do not change.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - merge by default (Priority: P1)

1. **When** a person runs `secret cookie import --as NAME` for an existing secret, **Then** the
   command merges the new jar with the old one by the key `(domain, path, name)`. The cookies of
   other domains stay.
2. **When** the new jar has a cookie with the same key, **Then** the new one wins (fresh value
   and expiry).
3. **When** the secret does not exist yet, **Then** the command just saves the new jar, as
   before.
4. The comment and `-x` are recomputed from the final set: `N cookies`, the list of session-only
   cookies, `-x` is the earliest expiry among the persistent cookies.

### User Story 2 - full overwrite by a flag (Priority: P2)

1. **When** a person runs `secret cookie import --as NAME --replace`, **Then** the command
   overwrites the whole secret with the new jar; the old cookies are not read and Touch ID is
   not needed.

## Requirements *(mandatory)*

- **FR-001**: `cookie import` by default merges the new jar with the existing secret by the key
  `(domain, path, name)`. The new key wins; the other cookies are kept.
- **FR-002**: `--replace` keeps the behaviour "overwrite fully" without a read of the old secret.
- **FR-003**: when the secret is missing, no merge is needed; the command saves the new jar.
- **FR-004**: after the merge, the command recomputes the comment and `-x` from the final set.
- **FR-005**: cookie values do not go to stdout, argv or the log. The merge goes in the command
  memory; the result goes into the store.
- **FR-006**: the daemon and the extension do not change: they call `cookie import` as before and
  get the merge by default.

## Success Criteria *(mandatory)*

- **SC-001**: a capture of portal.example.org, then of tax.example.org into one secret gives a
  jar with the cookies of **both** domains.
- **SC-002**: a repeated capture of the same domain updates its cookies and makes no duplicates.
- **SC-003**: `--replace` overwrites the secret and does not read the old one (no Touch ID).
- **SC-004**: cookie values stay out of stdout, argv and the log.
