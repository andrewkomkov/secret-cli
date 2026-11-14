# Tasks: SecretBar 2

**Input**: `specs/014-secretbar-v2/spec.md`

- [x] T001 `helper/store/main.swift`: `clip` (concealed type, test clipboard in the Test build), `status`
- [x] T002 `bin/secret`: `copy` in `dp` mode through `clip`
- [x] T003 `app/SecretBar/Model.swift`: `status`, poll every 5 and 30 seconds, agent log in the activity, projects, index of `.env` references, notifications
- [x] T004 `app/SecretBar/QuickPanel.swift`: quick panel, hotkey ⌥⌘S, HUD badge
- [x] T005 `app/SecretBar/MainWindow.swift`: main window — projects, list, card, forms, settings
- [x] T006 `app/SecretBar/Views.swift`: menu bar window — status, quick search, copy
- [x] T007 App icon: `app/SecretBar/Assets.xcassets`
- [x] T008 `--snapshot`, review of the images, layout fixes (SC-002). 2026-10-07: all screens in the light and dark theme are reviewed; fixed: the key in "How to use", the Russian text of "Activity", the capture method (R16)
- [x] T009 `tests/run.sh`: `clip`, `status`, `--selftest`, binary
- [x] T011 Apple Development signature and install into `/Applications`: without them, `linkd` does not accept App Intents (R15). Constitution 1.4.1
- [x] T012 `README.md`. 296 checks, 2026-10-07
- [x] T010 Live check 2026-10-08. The owner refused to check by hand; the agent checked the installed app on real data through Accessibility and screenshots. Checked: ⌥⌘S, search, main window, card, "Activity", "Settings", the accessibility tree, the Spotlight index (65 entries, `--spotlight-check`). The findings are fixed in 015. Not checked: copy (forbidden for the agent, art. I) and the display of notifications
