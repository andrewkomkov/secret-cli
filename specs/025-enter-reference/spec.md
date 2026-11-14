# Feature Specification: Enter copies the reference, a new secret from the panel

**Feature Branch**: `025-enter-reference`. The work goes on in `main`.

**Created**: 2026-10-23

**Status**: Done 2026-10-23

**Input**: The owner: "let's make ENTER copy the reference to the secret, and shift enter the secret itself. And I
still do not see a way to create a new secret from the panel at the top, with the reference to it going to the clipboard
right away".

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Enter and ⇧Enter (Priority: P1)

1. **When** a human presses ↩ on a secret in the quick panel ⌥⌘S, in the menu bar panel or in the list
   of the main window, **Then** the clipboard holds the reference `secret:NAME`. Touch ID is not necessary, the toast names the reference.
2. **When** a human presses ⇧↩, **Then** the clipboard holds the value, as ↩ gave before: Touch ID, clearing
   after 30 seconds.
3. A click on a row in the menu bar panel gives the reference, a ⇧-click gives the value. The hints at the bottom of the panels
   name both keys.

### User Story 2 - New secret from the panel (Priority: P1)

1. **When** a human clicks "+" in the header of the menu bar panel or presses ⌘N in the panel, **Then** the
   main window opens with the sheet "New secret".
2. **When** the search in the panel found nothing, and the query is a valid name, **Then** ↩ opens the sheet
   "New secret" with this name (in upper case). The empty list shows the button
   "Create NAME".
3. **When** a human saves the secret, **Then** the reference `secret:NAME` is in the clipboard (019).

## Requirements *(mandatory)*

- **FR-001**: one function for the choice of the action: ⇧ gives the value, without ⇧ the reference.
- **FR-002**: `Navigation.newSecret(name:)` passes the name to the create sheet.
- **FR-003**: `ru` translations for the new strings.

## Success Criteria *(mandatory)*

- **SC-001**: ↩ in any panel puts the reference without Touch ID.
- **SC-002**: from the menu bar panel, a new secret takes one click to the create sheet.
