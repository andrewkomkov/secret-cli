# Feature Specification: SecretBar 2

**Feature Branch**: `014-secretbar-v2`. The work goes on in `main` of the local repository.

**Created**: 2026-10-07

**Status**: Done 2026-10-08; fixes after the live check — `specs/015-secretbar-live-fixes`

**Input**: The owner asked if the app is perfect, and asked for an "ultra premium experience".
The review found weak points of the first version (012):

- The menu bar window closes when the Touch ID window or the file selection window takes the focus.
- Clipboard managers keep the copied value.
- The poll every 5 seconds starts 3 processes.
- No notifications, no icon, no hotkey.
- "Activity" does not show the Touch ID windows.
- Nobody checked the look of the app.

## User Scenarios & Testing *(mandatory)*

<!-- utr-100: 8.2 — the headings are set by the spec-kit template -->
### User Story 1 - Quick panel (Priority: P1)

1. **When** ⌥⌘S in any app, **Then** a search panel opens in the center of the screen.
2. **When** the owner types, **Then** the list narrows by name and comment.
3. **When** ↩, **Then** the value is in the clipboard, the panel is closed, the menu bar shows a "Copied" badge.
4. **When** Esc or a click outside, **Then** the panel is closed.

### User Story 2 - Main window (Priority: P1)

1. On the left: projects by comment, "All", "Expiring". In the middle: the list. On the right: the card: name,
   comment, expiry, references `secret:NAME` in project `.env` files, actions.
2. The forms to add, change, rename, delete and the settings work in the window. The
   Touch ID window and the file selection window do not close them.

### User Story 3 - Concealed copy (Priority: P1)

1. **When** copy, **Then** the clipboard holds the value with the type `org.nspasteboard.ConcealedType`.
   Clipboard managers do not keep it. Clearing after 30 seconds, as before.

### User Story 4 - Notifications and activity (Priority: P2)

1. A notification once a day: secrets expired or expire within 7 days.
2. A notification: the helper signature has less than 2 days left, or the helper does not start.
3. "Activity" shows the requests and the Touch ID windows.

### Edge Cases

- Notifications are not allowed in the system: the app works without them.
- Another app uses the hotkey: the app writes this in the settings.

## Requirements *(mandatory)*

<!-- utr-100: 1.9 — the IDs are set by the spec-kit template -->
- **FR-001**: helper `clip` reads the value from stdin and puts it into the clipboard with the concealed type.
  `secret copy` in `dp` mode uses it.
- **FR-002**: helper `status`: one line with launch, grace and idle time.
- **FR-003**: the app still does not access the keychain and does not read values into memory.
- **FR-004**: `--snapshot DIR`: each screen as PNG, light and dark theme, demo data.
- **FR-005**: the hotkey through Carbon `RegisterEventHotKey`, without the Accessibility permission.

## Success Criteria *(mandatory)*

<!-- utr-100: 1.9 — the IDs are set by the spec-kit template -->
- **SC-001**: Tests: `clip` on a separate clipboard sets the concealed type; `status`; `--selftest`;
  the binary has no keychain calls.
- **SC-002**: The `--snapshot` images are checked by eye: layout, both themes.
- **SC-003**: Manual check by the owner.
