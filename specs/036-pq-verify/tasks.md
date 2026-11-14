# Tasks: `touchid pq` checks the values before the write

- [x] T001 2026-11-14 `upgradePQ`: `unseal` of each new value, `check` and `wm` before `writeFile`
- [x] T002 2026-11-14 `tests/run.sh`: 560 of 560
- [x] T003 manual SC-002, 2026-11-14: the real store, 160 values. `secret touchid pq` — one Touch ID window, all 160 passed the open check, `post-quantum: on`. Then `secret run` with three names — a new Touch ID through the agent, three values read
