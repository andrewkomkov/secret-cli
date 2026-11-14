# Tasks: search for a secret by meaning with the on-device model

**Input**: `specs/034-fm-ask/spec.md`, `plan.md`

- [x] T001 [US1] `secret ls --ask QUERY [-l]` in `bin/secret`: parts of 40, schema with `enum`, `fm respond -m system`
- [x] T002 [US1] filter of the names by part, order of the answer, code 1 on an empty answer
- [x] T003 [US2] without `fm` or on an `fm` error: code 2, cause and advice
- [x] T004 tests with a stub `fm` in `tests/run.sh`
- [x] T005 usage, completion, README, README.ru, `docs/claude-md-secrets.md`. The site was not changed: it has no list of `ls` commands
- [x] T006 manual SC-002, 2026-11-11: the real `/usr/bin/fm` (AFM 3 Core Advanced) on the owner's Mac, a temporary keychain, 5 fictional secrets. "shop database password" (in Russian) → `SHOP_DB_PASSWORD` (3.5 s), "mail" (in Russian) → `BILLING_SMTP_PASS`, "where do I keep the S3 credentials" → `ETL_S3_KEY`. "kubernetes" with the first instruction gave a false name, with the second one empty (measured in spec.md)
