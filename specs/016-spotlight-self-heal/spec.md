# Feature Specification: SecretBar restores the Spotlight index itself

**Feature Branch**: `016-spotlight-self-heal`. The work goes on in `main` of the local repository.

**Created**: 2026-10-08

**Status**: Done 2026-10-08

**Input**: The agent checked the app on 2026-10-08 after the install of the 12:13 build. `tests/run.sh`
failed on the check "015: spotlight index of the installed app". `--spotlight-check` showed 0
entries with 65 secrets. After a restart of SecretBar, the index again had 65 entries.

The system erased the index of the app after the app built it at launch. The app
builds the index again only when the list of secrets changes. So an empty index stays
empty until a restart or until a new secret.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Spotlight finds secrets without a restart (Priority: P1)

1. **Given** Spotlight is on in the settings and the index of the app is empty or incomplete, **When**
   10 minutes pass, **Then** the app builds the index again. Spotlight again finds all
   secrets.
2. **Given** the index is complete, **Then** the app does not change the index.
3. **Given** Spotlight is off in the settings, **Then** the app does not build the index.

### Edge Cases

- The query to the index returned an error. The app does not change the index and checks it again after 10
  minutes.
- The list of secrets is empty. The app does not check the index.

## Requirements *(mandatory)*

- **FR-001**: at launch and every 10 minutes, the app compares the number of entries in its
  Spotlight index with the number of secrets. If they differ, the app builds the index again.
- **FR-002**: only names and comments go into the index. The index has no values.
- **FR-003**: `--spotlight-check` and the app count the entries with one function.

## Success Criteria *(mandatory)*

- **SC-001**: the agent clears the index of the app with the `--spotlight-clear` flag. After 10 minutes
  the index is complete again, and the app works without a restart.
- **SC-002**: `tests/run.sh` passes on the installed app.

## Assumptions

- The system clears the index, for example on a reinstall or a rebuild of Spotlight. The app
  does not know the cause. So it checks the result.
