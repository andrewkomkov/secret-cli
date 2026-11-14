# Tasks: Fewer keychain calls

- [x] T001 Attribute cache: `list_items` decodes in `awk`, one variable per item (`IC_<name>`), lookup without new processes. `get_comment`, `get_expiry`, the existence check in `check`, `run`, `restore` take the data from the cache
- [x] T002 Batch write: `import` writes the `security` items in one `security -i` session, the name cache is updated once at the end
- [x] T003 Measurement on 300 items (SC-001), `N=300 tests/bench.sh`, 2026-10-02:

  | Command | before | after |
  |---|---|---|
  | `import` 300 values | 33.8 s | 4.6 s |
  | `check` 300 keys | 6.1 s | 0.62 s |
  | `ls -l` | 0.44 s | 0.07 s |
  | `run` 5 references | 0.22 s | 0.15 s |
  | `set` | 0.17 s | 0.12 s |
  | `get` | 0.13 s | 0.07 s |

  The first version of the cache (one string and a bash pattern search) gave `import` 27 s and `check` 4.2 s: a search
  `${s#*pattern}` in a 12 KB string costs 6.5 ms, almost as much as a `security` call (12 ms).
- [x] T004 `tests/run.sh` in full (SC-002): 203 checks. A test was added: `import` keeps the comment and the expiry of an item that already exists
