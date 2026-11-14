# Research: items that only the helper reads

Prototype of 2026-10-02 on a temporary keychain (`specs/007-protected-items/spike/spike.swift`), UI turned off with
`SecKeychainSetUserInteractionAllowed(false)`, no system dialogs.

| # | Check | Result |
|---|---|---|
| R1 | ACL of an item that the helper created with `SecKeychainAddGenericPassword` | `decrypt` — only the helper, requirement `cdhash H"…"` (ad-hoc). `change_acl` — nobody without the password. `encrypt` — everyone |
| R2 | `SecKeychainItemSetAccess` after creation | `-128`: needs the UI. Not needed: the creator is already the only trusted one |
| R3 | Read after an ad-hoc rebuild | no access: the `cdhash` differs |
| R4 | Signing with a self-signed certificate | requirement `identifier and certificate leaf`, survives a rebuild. Not taken: the signing key would have to be stored, and it can sign a foreign binary |
| R5 | Read by a binary with another signature | `-25293`, no dialog (UI off) |
| R6 | Change of the comment by a binary with another signature | allowed (`0`) |
| R7 | Deletion by a binary with another signature | allowed (`0`) |
| R8 | Attributes through `security find-generic-password` without `-w` | read without a dialog |
| R9 | `codesign -o runtime` | the `runtime` flag: `DYLD_*` variables have no effect, a debugger without `get-task-allow` does not attach |

Conclusion: only the value is protected. A helper rebuild needs a migration of the items from the old helper to
the new one (R3). Attributes and deletion are not protected (R6, R7).
