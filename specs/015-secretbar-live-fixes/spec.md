# Feature Specification: SecretBar — fixes after the live check

**Feature Branch**: `015-secretbar-live-fixes`. The work goes on in `main` of the local repository.

**Created**: 2026-10-08

**Status**: Done 2026-10-08

**Input**: The owner will not check the app by hand and asked to do everything without him.
On 2026-10-08 the agent went through the installed SecretBar on real data: hotkey, main
window, card, "Activity", "Settings", the accessibility tree (VoiceOver). Values were not
copied: copy is forbidden for the agent. Found:

1. Search does not find a secret if the string is typed in the Russian layout (`github` typed on Russian keys instead of `github`).
2. A section without secrets ("Expiring"): the search field moves to the middle of the window.
3. The card of a secret that is not in the current list stays on the right.
4. "How to use" suggests a `.env` key without the project prefix, but the key in the file is different
   (`ADMIN_PASSWORD` instead of `JENKINS_ADMIN_PASSWORD`).
5. VoiceOver: the grace icon reads as "Unlock", the buttons that copy commands as "Copy",
   the search field has no label, the actions button reads as "More".
6. Nobody can check the Spotlight index without a human: `mdfind` does not see the entries of the app.
7. The behavior on a large list (hundreds of secrets) is not checked.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Search in any layout (Priority: P1)

1. **When** the owner types `github` on Russian keys, **Then** the panel, the main window and Spotlight find
   `GITHUB_TOKEN`, as for `github`. The reverse is also true: the Russian word for "secret" typed on English keys finds that Russian word.
2. Matches on the source string come first.

### User Story 2 - List and card agree (Priority: P1)

1. Empty section: the search field at the top, below it a note why the section is empty.
2. The card on the right is only for a secret from the current list.
3. "How to use" shows the key under which the secret is written in `.env`, if a reference exists.

### User Story 3 - VoiceOver (Priority: P2)

1. Each button and each meaningful icon has a Russian label: grace state, command
   copy, search, actions.

### User Story 4 - Checks without a human (Priority: P2)

1. `SecretBar --spotlight-check` prints the number of entries of the app in the Spotlight index.
2. `--selftest` checks search in the other layout and the search time on 2000 secrets.
3. `--snapshot` captures an empty section and a list of 300 secrets.

## Requirements *(mandatory)*

- **FR-001**: search adds to the result the string converted to the other layout (JCUKEN ↔
  QWERTY), if the query has only letters of one layout.
- **FR-002**: the app still does not access the keychain and does not read values.
- **FR-003**: the reference index keeps the `.env` key for each reference `secret:NAME`. The key is
  only a variable name (`^[A-Za-z_][A-Za-z0-9_]*$`, up to 64 characters): a `.env` of another repository can
  hold any text before `=secret:`, and the line with the key is copied to the clipboard.
- **FR-004**: `--spotlight-check` only reads the index of the app through `CSSearchQuery`.

## Success Criteria *(mandatory)*

- **SC-001**: all 7 findings are closed; the snapshots and `--selftest` show this.
- **SC-002**: search on 2000 secrets is faster than 50 ms.
- **SC-003**: `tests/run.sh` passes.
