# Feature Specification: SecretBar — "New secret…" in the menu and a reference after create

**Feature Branch**: `019-secretbar-new-secret-link`. The work goes on in `main`.

**Created**: 2026-10-22

**Status**: In progress

**Input**: The owner: "add the item 'New secret…' to the drop-down menu of the menu bar window. When
a secret is created from the UI, the reference to it is copied to the clipboard automatically."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - New secret from the menu bar (Priority: P1)

1. **Given** the SecretBar window in the menu bar is open, **When** the person selects "…" → "New
   secret…", **Then** the main window opens with the sheet to create a secret.
2. If the main window is already open and another sheet is open in it, the new sheet does not open
   on top.

### User Story 2 - Reference in the clipboard after create (Priority: P1)

1. **When** the person saves a new secret (typed or generated), **Then** the clipboard
   holds `secret:NAME`, the toast says "NAME saved · reference secret:NAME in the clipboard".
2. If the save fails, the clipboard does not change.
3. A change or a rename of an existing secret does not change the clipboard.
4. The value of the secret does not go into the clipboard.

## Requirements *(mandatory)*

- **FR-001**: the "…" menu of the menu bar window has the item "New secret…".
- **FR-002**: the item opens the main window and the create sheet.
- **FR-003**: after a successful create from the UI, the reference `secret:NAME` is in the clipboard.
- **FR-004**: the `secret` command does not change.

## Success Criteria *(mandatory)*

- **SC-001**: a new secret from the menu bar — two clicks to the create sheet.
- **SC-002**: right after "Save", the reference can be pasted into `.env` without a separate copy.

## Assumptions

- The reference is the `secret:NAME` format from the constitution (V), the same as for "Copy reference".
- A create from the CLI (`secret set`, `secret ask`) does not touch the clipboard.
