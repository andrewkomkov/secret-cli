# Tasks: cookie import merges the jar

**Input**: `specs/031-cookie-jar-merge/spec.md`

- [x] T001 [US1] `cmd_cookie import`: for an existing secret, read the old jar and merge it with the new one by the key `domain|path|name`, the new key wins
- [x] T002 [US1] recompute the comment and `-x` from the final set after the merge
- [x] T003 [US2] flag `--replace`: overwrite without a read of the old secret and without Touch ID
- [x] T004 usage/docs: README, README.ru, site, `docs/claude-md-secrets.md` — merge by default, `--replace`
- [x] T005 `tests/run.sh`: merge of two domains, key update without duplicates, `--replace`, no values in the output
- [ ] T006 manual on the real extension: a capture of portal + tax into one secret gives the cookies of both; date — when done
