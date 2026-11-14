# Quickstart: check of the lease

## Automated tests

```bash
tests/run.sh
```

Checks of 026 in the test build: lease after `test-lock`, `not leased` for another name,
`test-sleep`, end by `SECRET_TEST_MAX_LEASE`, `--revoke`, `lock`, `set` removes the name,
`--for 25h`, Touch ID refusal.

## Manual check (SC-005, SC-006)

1. `secret ls -l` — choose two names, A and B.
2. `secret lease --for 1h A`. The Touch ID window names A and 1h. Give Touch ID.
3. `secret lease status` — A and the end time.
4. Lock the screen. After a minute, run from a scheduled job or over ssh:
   - `secret run --mask A -- sh -c 'test -n "$A" && echo ok'` — `ok`.
   - `secret run --mask B -- true` — at once `not leased: B`.
5. Put the Mac to sleep for 5 minutes. Repeat step 4 for A — `ok`.
6. Run `secret lease --revoke`. Repeat step 4 for A — `not leased: A`.
7. SecretBar: with an active lease the lease line is visible, the revoke button works.
