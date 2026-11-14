# Contract: SecretStore

Call: `build/SecretStore.app/Contents/MacOS/SecretStore COMMAND ...`. Hex uses lowercase digits,
`-` is an empty field.

Exit codes:

- Code 0: success.
- Code 1: error.
- Code 3: no item.
- Code 4: item without protection.
- Code 5: no Touch ID confirmation, or Touch ID is necessary with `SECRET_NO_DIALOG=1`.
- Code 64: incorrect call.

Only `policy` accepts the names `__secret-cli.*`. The commands `read`, `write`, `attrs`, `delete`
and the agent reject these names.

| Command | Touch ID | Output |
|---|---|---|
| `list` | no | `NAME<TAB>COMMENT<TAB>EXPIRY` one per line, sorted by name, `-` for empty; items `__secret-cli.*` are hidden |
| `has NAME` | no | code 0 or 3 |
| `read REASON NAME...` | yes, through the agent | `hex(value)` one line per name, in the order of the names |
| `write` | no | stdin: lines `hex(name) hex(value) hex(comment) hex(expiry)`; the item is replaced |
| `attrs REASON NAME COMMENT EXPIRY` | yes, through the agent | — |
| `delete NAME...` | no | code 3 if there is no item |
| `policy show` | no | `grace=N` from the policy attribute, `none` |
| `policy init [N]` | no | the first policy of an empty store; if a policy exists, it does not change; a store with items and no policy is an error (grace 0, change it with `policy grace`) |
| `policy grace N` | yes, always new, in the client itself | the policy is written again, the agent stops; the new grace is in effect from the next Touch ID |
| `lock` | no | the agent stops |
| `profile` | no | profile end, Unix seconds |
| `agent` | — | internal: the agent process |
| `wipe` | no | only the `Test` build: delete all items of the run account |

## Agent protocol

Socket `~/.local/state/secret/agent.sock` (`Test` build: `$SECRET_TEST_STATE/agent.sock`).
A request is one line with fields separated by the tab character (TAB). A response is one line.

- `read<TAB>nodialog 0|1<TAB>hex(reason)<TAB>hex(name),hex(name)...` → `ok<TAB>hex(value),...`
- `attrs<TAB>nodialog<TAB>hex(reason)<TAB>hex(name)<TAB>hex(comment)<TAB>hex(expiry)` → `ok`
- `lock` → `ok`, the agent stops
- error → `err<TAB>code<TAB>message`

The agent checks the uid of the client (`getpeereid`). The first request after the start or after
the end of grace asks for Touch ID. The agent reads the policy with this context. Grace 0: the
agent stops after the response. Without a confirmed context, the agent stops after 30 seconds idle.
