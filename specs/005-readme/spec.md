# Feature Specification: README

**Feature Branch**: `005-readme` (the work is done in `main` of the local repo)

**Created**: 2026-10-02

**Status**: Done — 2026-10-02

**Input**: The owner wants a modern README: the first screen makes clear what it is, why, and how to
start.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Understand in one minute (Priority: P1)

A person opens the README and on the first screen sees: what the command does, how it differs,
how to install it, and the first example.

**Acceptance Scenarios**:

1. **Then** at the top: the name, one line about the purpose, badges (macOS, bash, tests), navigation.
2. **Then** the quick start is no more than 6 commands.
3. **Then** a diagram: how the agent gets a secret and does not see the value.
4. **Then** the commands are split into groups, the full reference is collapsed.
5. **Then** the threat model: what is protected and what is not, as a table.

## Requirements *(mandatory)*

- **FR-001**: Everything that was in the README stays: commands, variables, limits, backup, Touch ID, hook, tests.
- **FR-002**: Stale lines are fixed: Touch ID exists, the tests check a locked keychain through the helper.
- **FR-003**: No emoji. The diagram is Mermaid (GitHub and Markdown editors draw it).

## Success Criteria *(mandatory)*

- **SC-001**: All commands from `secret help` are in the README.
- **SC-002**: The number of tests in the badge matches the output of `tests/run.sh`.
