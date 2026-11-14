# Feature Specification: Sliding grace

**Feature Branch**: `010-sliding-grace`. The work is done in `main` of the local repository.

**Created**: 2026-10-07

**Status**: Draft

**Input**: In the data protection store, grace lasts 300 seconds from Touch ID. The agent calls
`secret run` less often than once in 5 minutes. Because of this, the owner sees the Touch ID
window for almost each request. The owner chose a sliding grace (2026-10-07).

## User Scenarios & Testing *(mandatory)*

<!-- ste: E8.2 — the spec-kit template sets this heading -->
### User Story 1 - A question only after idle time (Priority: P1)

**Why this priority**: this is the goal of the feature.

**Independent Test**: test build, idle time 2 seconds. Requests each second for 5 seconds give
one Touch ID answer. A request after 3 seconds without requests gives a new question.

**Acceptance Scenarios**:

1. **Given** idle time N seconds, **When** the time between requests is less than N seconds,
   **Then** only the first request needs Touch ID.
2. **When** N seconds go by without requests, **Then** the next request asks for Touch ID.
3. **Given** the first Touch ID was 8 hours ago, **When** a request comes, **Then** a new
   Touch ID is necessary. The breaks between requests have no effect on this.

<!-- ste: E8.2 — the spec-kit template sets this heading -->
### User Story 2 - End of grace on screen lock and sleep (Priority: P1)

**Why this priority**: a sliding grace can last for hours. A locked screen means that the owner
is not at the Mac.

**Independent Test**: test build. After the lock signal, the next request asks for Touch ID.

**Acceptance Scenarios**:

1. **When** the owner locks the Mac screen, **Then** the agent ends grace immediately.
2. **When** the Mac goes to sleep, **Then** the agent ends grace immediately.
3. **When** `secret lock` runs, **Then** the agent ends grace immediately, as before.

<!-- ste: E8.2 — the spec-kit template sets this heading -->
### User Story 3 - Setting and status (Priority: P2)

**Acceptance Scenarios**:

1. **When** `secret touchid grace N` runs, **Then** after Touch ID the idle time is N. N more
   than 3600 is an error.
2. **When** `secret touchid status` runs, **Then** the command shows the idle time, the 8-hour
   limit and the grace state: active until which time, or not active.
3. **Given** the policy `grace=300` from feature 009, **Then** the command reads it as idle
   time 300.

### Edge Cases

- A new store without a policy: idle time 0, Touch ID for each command.
- The agent crashed: the next request asks for Touch ID.
- The Mac clock was changed: the 8-hour limit is counted by the monotonic clock of the process.

## Requirements *(mandatory)*

<!-- ste: E1.9 — the spec-kit template sets the requirement IDs -->
### Functional Requirements

- **FR-001**: After each served request, the agent sets the end of grace: now plus the idle
  time. The end of grace is not later than 8 hours from Touch ID.
- **FR-002**: The agent stops on screen lock and on Mac sleep.
- **FR-003**: The policy format stays the same: `grace=N`. Now N is the idle time.
- **FR-004**: The new default policy: idle time 1800 seconds.
- **FR-005**: `touchid status` shows the idle time, the limit and the grace state. This does not
  need Touch ID.
- **FR-006**: Test build: the limit comes from an environment variable, the lock signal is a
  command of the test build. The release build does not have this code.

### Key Entities

- **Policy**: the idle time in seconds.
- **Agent**: the time of Touch ID, the end of grace.

## Success Criteria *(mandatory)*

<!-- ste: E1.9 — the spec-kit template sets the criteria IDs -->
- **SC-001**: Test: requests more frequent than the idle time give one Touch ID question. Idle
  time gives a new question.
- **SC-002**: Test: the limit gives a new question during continuous requests.
- **SC-003**: Test: the lock signal gives a new question.
- **SC-004**: Manual check: a screen lock by the owner ends grace.

## Assumptions

- During grace, the agent answers any process of the owner, as in feature 009. A sliding grace
  makes this time longer. Screen lock, sleep and the 8-hour limit restrict it.
- Only the owner changes the idle time with `secret touchid grace N`: the hook does not let the
  agent do it.
