# Research: metadata items

| # | Check | Result |
|---|---|---|
| R12 | Touch ID windows in the `coreauthd` log, 2026-10-07 | 382 windows in 3 hours. For the first `secret run`: 3 windows: `policy show`, `list` and the agent. For each next one: 2 windows. ACL operation `od` |
| R13 | `secret ls` after R12 | a Touch ID window for `policy show`. The owner clicked Cancel, the helper got `-128` |
| R14 | Production store after 011 | `ls`, `ls -l`, `has`, `touchid status`: 0 windows. Two `secret run` in a row: 1 window. The agent loaded 49 values without system windows |
