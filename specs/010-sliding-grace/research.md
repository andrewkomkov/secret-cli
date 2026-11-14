# Research: sliding grace

| # | Check | Result |
|---|---|---|
| R11 | Lifetime of a confirmed `LAContext` for the keychain, 2026-10-07, production store | the context was confirmed at 14:31:11. At 14:41 the system window "SecretStore needs to authenticate to continue" appeared. The cause was not confirmed: the short process `policy show` could also open the window, not the agent (011 R12). Values in the agent memory cover both cases |

## Decision

After Touch ID, the agent reads all items and keeps the values in memory until the end of grace.
A request gets the value from memory if the item reference (`kSecReturnPersistentRef`) did not
change: an item is rewritten by delete and create, and the reference changes. If the value is
not in memory or the reference is different, the agent reads the item. If the context is older
than 8 minutes, the agent first asks for Touch ID with its own text. The Touch ID window always
shows the text of the helper.

`attrs` (`note`, `expire`) rewrites the item with the value from memory: delete and create do not
need Touch ID (research 009 R8).

Alternatives:
- Keep only the context. Then the window appears each 10 minutes.
- Go back to grace 300 seconds. The owner asked for fewer questions.
