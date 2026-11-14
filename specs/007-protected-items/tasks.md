# Tasks: Items that only the helper reads

**Input**: `specs/007-protected-items/` (spec.md, plan.md, research.md)

## Phase 1: Helper

- [x] T001 `secret-auth`: `status`, `auth`, the common part (open the keychain, turn off the UI, find an item)
- [x] T002 `read KC REASON NAME...`: policy and grace, Touch ID, `not protected` for a foreign item
- [x] T003 `write KC NAME [--comment] [--expiry] [--keep-attrs]`, replacement of a foreign item through `NAME#new`
- [x] T004 `delete`, `policy init|grace|remove`, the grace stamp with HMAC
- [x] T005 Build with `-D SECRET_TEST`: the Touch ID answer from the file `SECRET_TEST_AUTH`

## Phase 2: bin/secret

- [x] T006 Mode: protected if `__secret-cli.policy` exists; read and write through the helper; `__secret-cli.*` hidden in `ls`
- [x] T007 `touchid on`: policy and migration of all items; `touchid off`: back to `security`; `touchid grace` through the policy; `status`
- [x] T008 Remove the config `~/.config/secret/config` and the old `require_auth`: Touch ID only in the helper

## Phase 3: install.sh

- [x] T009 Ad-hoc signature with hardened runtime, source hash, migration old → new helper, rollback on error

## Phase 4: Tests

- [x] T010 Protected item: read by the helper, refusal to another binary without a dialog (SC-001)
- [x] T011 Migration on helper update (SC-002), interrupted migration `NAME#new`
- [x] T012 Replaced item → `not protected` (SC-003); deleted policy → grace 0; fake stamp
- [x] T013 The old tests in normal and in protected mode

## Phase 5: Check and documents

- [ ] T014 Manual check SC-004 on the owner's keychain
- [x] T015 README (threat model), `secret help`, `CLAUDE.md`, `docs/claude-md-secrets.md`; hook: remove the rules about the Touch ID config, which no longer exists
