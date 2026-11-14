# Implementation Plan: cookie import merges the jar

**Spec**: `specs/031-cookie-jar-merge/spec.md`

## Technical Context

### `cmd_cookie import` in `bin/secret`

- Arguments: `--as NAME` (exists), `--domain D` (exists), new `--replace`.
- It reads the new jar from stdin into memory.
- If there is **no** `--replace` and the secret exists (`has NAME`): it reads the secret value by
  the same path as `cmd_run`/`cmd_get` (read from the store → Touch ID) and decodes the base64
  into the old jar.
- Merge by key: the key is `domain|path|name`, where `domain` is without the prefix
  `#HttpOnly_`. From the old jar, it takes the cookies whose key is not in the new one. It adds
  all cookies of the new jar to them. The header `# Netscape HTTP Cookie File` is one.
- Recompute the comment and `-x` from the final set: `N cookies`, the list of session-only
  cookies (expiry 0), `-x` is the minimum positive expiry.
- It encodes the result in base64 and writes it through the `cmd_set` path (value through a
  pipe, not argv).
- `--replace`: it does not read the old secret, Touch ID is not needed, it behaves as now.

The merge goes in awk/bash over the jar lines. The values stay in the lines and get only into the
store.

### Tests (tests/run.sh)

- import a jar of domain A → import a jar of domain B into the same NAME → `cookie ls --jar NAME`
  shows the cookies of both domains.
- a repeated import of domain A with a new value → the same key is updated, no duplicates.
- `--replace` → only the last jar is in the secret.
- the values do not appear in the stdout of `import`/`ls`.

## Constitution Check

- **I**: the merge is in the command memory; values do not go to stdout/argv/log. `ls --jar`
  gives only metadata.
- **II**: the merge reads the secret → Touch ID, as any read. `--replace` writes without a read,
  without Touch ID.
- **III**: only bash/awk, no new dependencies.
- **IV**: `tests/run.sh` on the test store checks the merge, the key update, `--replace`.
- **V**: new flag `--replace`. The behaviour of `import` changes (merge by default) — see the
  deviation below.

## Complexity Tracking

| Deviation | Reason |
|---|---|
| `import` merges by default instead of overwriting | One secret collects the sessions of several sites. The old behaviour lost the cookies of other domains (owner's request). `--replace` brings back the overwrite. |
| `import` now reads the secret (Touch ID) | A merge is not possible without the old jar. `--replace` does not do the read. |
