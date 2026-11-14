# Feature Specification: Secret lease for agents

**Feature Branch**: `026-agent-lease`. The work goes on in `main` of the local repo.

**Created**: 2026-11-03

**Status**: Draft

**Input**: A screen lock ends grace at once (principle II). On a locked Mac, Touch ID cannot be
asked. So an agent that works while the owner is away is left without secrets. The owner
chose a lease (2026-11-03): an explicit set of secrets for up to 24 hours. The lease survives
a screen lock and a Mac sleep. The agent can request the lease itself; the owner gives Touch ID.

## User Scenarios & Testing *(mandatory)*

<!-- utr-100: 8.2 — heading set by the spec-kit template -->
### User Story 1 - The agent works while the screen is locked (Priority: P1)

The owner leaves the Mac. Before that, the agent requests a lease of the secrets it needs, and
the owner confirms with Touch ID. The owner locks the screen. The agent continues its work and
gets these secrets.

**Why this priority**: this is the goal of the feature.

**Independent Test**: test build. `secret lease SHOP_DB_PASSWORD`, test Touch ID "yes".
Screen lock signal. `secret run --mask SHOP_DB_PASSWORD -- cmd` works without a Touch ID
question.

**Acceptance Scenarios**:

1. **Given** a lease of `SHOP_DB_PASSWORD`, **When** the screen is locked and `secret run` reads
   `SHOP_DB_PASSWORD`, **Then** the command gets the value without a Touch ID question.
2. **Given** a lease of `SHOP_DB_PASSWORD`, **When** the Mac was asleep and woke up, **Then** the
   lease is in effect.
3. **Given** a lease of only `SHOP_DB_PASSWORD`, **When** the screen is locked and `secret run`
   reads `BILLING_API_KEY`, **Then** the command at once gives the error
   `not leased: BILLING_API_KEY`. The command opens no window and exits at once.
4. **Given** a lease and an unlocked screen, **When** `secret run` reads a secret from the lease,
   **Then** the command gets the value without Touch ID. For a secret outside the lease, the
   grace rules of feature 010 apply.

<!-- utr-100: 8.2 — heading set by the spec-kit template -->
### User Story 2 - Lease request and confirmation (Priority: P1)

**Why this priority**: without the owner's confirmation there is no lease.

**Independent Test**: test build, Touch ID answer from a file. "Yes" gives a lease, "no" gives
an error and no lease.

**Acceptance Scenarios**:

1. **When** `secret lease --for 6h SHOP_DB_PASSWORD SHOP_API_KEY`, **Then** the Touch ID window
   names both names and the term. After "yes", the command shows the names and the end time of
   the lease.
2. **When** `secret lease -e .env`, **Then** all names from the `secret:NAME` references of this
   file go into the lease.
3. **When** an agent runs `secret lease`, **Then** the Touch ID window opens the same way. The
   hook does not stop this command.
4. **When** the owner answers "no" or closes the window, **Then** the command gives an error and
   there is no lease.
5. **When** grace is active, **Then** `secret lease` still asks for a new Touch ID.
6. **When** the screen is locked, **Then** `secret lease` gives an error at once: Touch ID cannot
   be asked on a locked screen.
7. **When** `--for` is more than 24 hours or a name is not found, **Then** error, no lease.

<!-- utr-100: 8.2 — heading set by the spec-kit template -->
### User Story 3 - End of the lease (Priority: P1)

**Why this priority**: a lease lasts long. The owner must know its term and be able to end it.

**Independent Test**: test build, lease limit from an environment variable.

**Acceptance Scenarios**:

1. **Given** a lease for N hours, **When** N hours have passed, **Then** a read gives
   `not leased: NAME`. Requests do not extend the term. Mac sleep time counts toward the term.
2. **When** `secret lease --revoke`, **Then** the command ends all leases at once.
3. **When** `secret lock`, **Then** the command ends grace and all leases.
4. **When** the Mac restarts or the owner logs out, **Then** there is no lease.
5. **When** `secret set` or `secret ask` changes a leased secret, **Then** this secret leaves
   the lease. The command no longer gives the old value.

<!-- utr-100: 8.2 — heading set by the spec-kit template -->
### User Story 4 - Status, log and SecretBar (Priority: P2)

**Acceptance Scenarios**:

1. **When** `secret lease status`, **Then** the command shows the leased names and the end time
   of each. No values, no Touch ID needed.
2. **When** `secret log`, **Then** a read from the lease is marked as `lease`.
3. **Given** a lease, **Then** SecretBar shows that a lease exists, how many names it holds and
   when its term ends. A button in SecretBar revokes all leases.

### Edge Cases

- Two leases in a row: the names add up. Each name has its own end. If a name is already
  leased, the later end stays.
- `secret lease` with `SECRET_NO_DIALOG=1`: error, no lease.
- The store is the file keychain (before `secret migrate`): `secret lease` fails with the error
  `lease needs the secure enclave store`.
- The helper process that holds the lease crashed: there is no lease, the next request follows
  the normal rules.
- The Mac clock was changed: the lease term is counted by monotonic clocks that include sleep.
- A secret was deleted (`secret rm`) during the lease: it leaves the lease.
- Empty set of names (for example, a `.env` without references): the command gives an error
  before the Touch ID window.

## Requirements *(mandatory)*

<!-- utr-100: 1.9 — requirement IDs set by the spec-kit template -->
### Functional Requirements

- **FR-001**: New command `secret lease [--for DURATION] NAME... | -e FILE`. DURATION is a
  number with `m` or `h`. The default is 8 hours. More than 24 hours is an error.
- **FR-002**: Each lease requires a new Touch ID. Grace does not replace it. The window text
  names the names and the term.
- **FR-003**: The lease holds the values of only the named secrets. After a screen lock, the
  helper gives only these values.
- **FR-004**: A screen lock and a Mac sleep end grace, as before, and do not end the lease.
- **FR-005**: The lease term counts from the Touch ID. Requests do not extend the term.
- **FR-006**: These end the lease: end of the term, `secret lease --revoke`, `secret lock`,
  restart, logout, change or deletion of a secret (only for that name).
- **FR-007**: If the screen is locked and a name is not in the lease, the command at once gives
  the error `not leased: NAME`. The error names all such names. The command exits without a
  window.
- **FR-008**: `secret lease status` shows only the names and the end time. The command works
  without Touch ID.
- **FR-009**: `secret log` writes the mark `lease` for a read from the lease. The lease request
  and the revoke also go into the log.
- **FR-010**: The PreToolUse hook lets `secret lease`, `secret lease status` and
  `secret lease --revoke` through.
- **FR-011**: SecretBar shows an active lease and revokes it. New interface strings get the
  `ru` translation in the same change.
- **FR-012**: `docs/claude-md-secrets.md` tells the agent: before long work while the owner is
  away, request a lease of the names you need. On the error `not leased`, stop and tell the
  owner.
- **FR-013**: Test build: the lease limit and the lock signal come from the environment and a
  test-build command. The release build does not have this code.
- **FR-014**: The constitution (principle II) gets the lease rule: an explicit set, Touch ID for
  each lease, a term of up to 24 hours. A lock and a sleep keep the lease. This is a separate
  commit with a new constitution version.

### Key Entities

- **Lease**: secret name, value in the helper memory, Touch ID time, end time.
- **Grace**: as in feature 010, no changes.

## Success Criteria *(mandatory)*

<!-- utr-100: 1.9 — criterion IDs set by the spec-kit template -->
- **SC-001**: Test: after the lock signal, a leased secret is read, and a secret outside the
  lease gives `not leased` in less than 1 second.
- **SC-002**: Test: the end of the term ends the lease under continuous requests.
- **SC-003**: Test: `--revoke` and `lock` end the lease. `set` removes the name from the lease.
- **SC-004**: Test: `--for 25h` gives an error. The Touch ID answer "no" gives no lease.
- **SC-005**: Manual check: the agent requested a lease, the owner gave Touch ID and locked the
  screen for 30 minutes. The agent got the leased secret and an error for another secret.
- **SC-006**: Manual check: the lease works after a Mac sleep.

## Assumptions

- During the lease, the helper gives the leased values to any process of the owner, as in
  grace (features 009, 010). The lease makes this time longer, but only for an explicit list of
  names.
- On a locked Mac, a person at the keyboard cannot run a command. So a lease during a screen
  lock is safe.
- The owner sees the names and the term in the Touch ID window and decides whether to give the
  lease.
- The agent keeps the Mac awake itself if the work goes on at night. The lease does not do it.
- The lease works only in the Secure Enclave store. The file keychain stays as before.
