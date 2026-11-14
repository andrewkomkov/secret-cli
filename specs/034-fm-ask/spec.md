# Feature Specification: search for a secret by meaning with the on-device model

**Feature Branch**: `034-fm-ask`

**Created**: 2026-11-11

**Status**: Draft 2026-11-11

**Input**: Owner: "something specific to macOS 27, FM". macOS 27 has `/usr/bin/fm`: a command
to the on-device Apple Foundation Model.

## Goal

A person or an agent searches for a secret with words: `secret ls --ask "shop database
password"`. The command prints the names that fit. The model sees only names and comments; it
does not see the values.

## Probe of 2026-11-11

5 secrets, `fm respond -m system -g --no-stream --schema`. The schema limits the answer to an
array of names from the list (`enum`):

| Query | Answer | Time |
|---|---|---|
| database password of the shop | `SHOP_DB_PASSWORD` | 4.4 s (first run) |
| mail | `BILLING_SMTP_PASS` | 1.3 s |
| github token (in Russian) | `GITHUB_TOKEN` | 1.1 s |
| kubernetes cert | empty | 0.7 s |

Without `enum`, the model made up names (`Postgres`, `Stripe`). So `enum` is required.

The instruction is also important. Probe of 2026-11-11, the same 5 secrets, 7 queries:

| Instruction | Errors |
|---|---|
| "Pick the secrets whose name or comment fits the query. Return an empty list when nothing fits." | `kubernetes` gave all 5 names, `vpn` gave `SHOP_DB_PASSWORD` |
| "Pick only the secrets that are clearly about the subject of the query. If no secret is about it, return an empty list. Do not guess." | none: 7 of 7 |

The command uses the second instruction.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - search with words (Priority: P1)

1. **When** a person runs `secret ls --ask QUERY`, **Then** the command prints the names that
   fit, one per line, the best first.
2. With `-l`, the command prints the name, the expiry and the comment, as `ls -l`.
3. If nothing fits, the command prints nothing and exits with code 1.
4. The query can be in any language that the model understands.

### User Story 2 - without the model (Priority: P1)

1. **When** `fm` is missing, Apple Intelligence is off or the `fm` license is not accepted,
   **Then** the command prints the cause and the advice `secret ls -l | grep -i WORD`. Exit
   code 2.

### Edge Cases

- Many secrets: the command splits the list into parts of 40 lines and asks the model for each
  part.
- The model returned a name not from the list: the command drops it.
- Only the on-device model (`-m system`). The command does not use Private Cloud Compute and
  external providers.

## Requirements

- **FR-001**: `secret ls --ask QUERY [-l]`. A new flag; the old forms of `ls` do not change.
- **FR-002**: only names and comments go to `fm`. The list and the query go through stdin.
- **FR-003**: the answer schema is an object with the array `names`; the items are an `enum` of
  the names of the part.
- **FR-004**: the path to `fm` is `SECRET_FM` in tests (a stub), otherwise `/usr/bin/fm`.
- **FR-005**: `ls --ask` does not ask for Touch ID and does not read values.

## Success Criteria

- **SC-001**: tests with a stub `fm`: the names are printed; a name not from the list is dropped;
  an empty answer gives code 1; no `fm` gives code 2 and the advice; the stub does not see values;
  `-m system` is in the arguments.
- **SC-002**: manual check on the owner's Mac with the real `fm`. Date — when done.
