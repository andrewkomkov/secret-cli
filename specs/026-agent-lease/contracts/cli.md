# Contract: command `secret lease`

```text
secret lease [--for DURATION] NAME...    lease of names; DURATION: Nm or Nh, default 8h, up to 24h
secret lease [--for DURATION] -e FILE    lease of the names from the secret:NAME references in FILE
secret lease status                      names and end time, no values and no Touch ID
secret lease --revoke                    end all leases
```

## Output

- `lease` (stderr): `leased until 2026-11-04 03:15: SHOP_API_KEY, SHOP_DB_PASSWORD`.
- `lease status` (stdout), one line per name: `NAME<TAB>YYYY-MM-DD HH:MM`. Without a lease:
  empty output and `no lease` in stderr, code 0.
- `lease --revoke` (stderr): `lease revoked`.

## Errors

| Case | Message | Code |
|---|---|---|
| `--for` more than 24h or a wrong form | `lease: --for must be 1m..24h` | 64 |
| no names | `lease needs NAME... or -e FILE` | 64 |
| name not found | `not found: NAME` | 3 |
| file keychain | `lease needs the secure enclave store` | 1 |
| screen locked | `lease needs Touch ID: the screen is locked` | 6 |
| `SECRET_NO_DIALOG=1` | `Touch ID confirmation needed, SECRET_NO_DIALOG is set` | 5 |
| Touch ID refusal | as `read` does now | 1 |
| read outside the lease during a lock | `not leased: A, B` | 6 |

## Touch ID window

`secret: lease SHOP_API_KEY, SHOP_DB_PASSWORD for 6h` (a list longer than 5 names: the first 5
and `and N more`).

## Agent protocol (internal)

- `lease<TAB>nodialog<TAB>hex(reason)<TAB>seconds<TAB>hex(name),...` → `ok<TAB>end_epoch`
- `lease-status` → `ok<TAB>hex(name):end_epoch,...`
- `revoke` → `ok`
- `read` → `ok<TAB>values<TAB>sources`, sources: `l` or `g` for each name.

## Status line for SecretBar

`secret-vault status` gets the field `lease=N:END_EPOCH` (N names, the nearest end). The old
field `grace=` stays.
