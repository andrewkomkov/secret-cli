# Tasks: launch on the international market

**Input**: `specs/024-global-launch/spec.md`

- [x] T001 [US1] `bin/secret`: `VERSION`, `secret version`, `--version`, usage, completion, test
- [x] T002 [US1] SecretBar: English strings in the code, `Parse.other`, `developmentRegion = en`
- [x] T003 [US1] SecretBar: `Localizable.xcstrings` with `ru`, keys compared with the build
- [x] T004 [US1] 2026-10-23: `--snapshot` images in `en` and `ru`, no strings of the other language. The settings screen shows the path of the command, it does not go to the site
- [x] T005 [US1] `README.md` in English, `README.ru.md`, comments in `hooks/` and in the completion
- [x] T006 [US2] `.github/workflows/ci.yml`, 2026-10-23: the run is green, 339 checks on macos-15, SecretBar is built
- [x] T007 [US2] release-please: config, manifest, `.github/workflows/release.yml`, formula job. 2026-10-23: PR #1 "release 1.2.0" is open
- [x] T008 [US2] tap: `.github/workflows/test.yml`, 2026-10-23: install, test, audit pass
- [x] T009 [US2] Actions permissions in the repository, description and topics of the repository
- [x] T010 [US3] `site/`: page, animations, reduced motion, theme, phone
- [x] T011 [US3] `.github/workflows/pages.yml`, Pages is on, the page opens. Lighthouse 2026-10-23: light theme 100/100/100/100, dark theme — performance 94, the rest 100
- [x] T012 constitution 2.3.0, `CLAUDE.md` (release order)
- [ ] T013 manual: the owner stores `HOMEBREW_TAP_TOKEN`, the release PR is merged, the formula is updated. 2026-10-23: PR #1 merged, v1.2.0 released, the tap CI passed. No token, the formula job skipped the step, formula 1.2.0 was updated by hand. Left: the token and a check of the automatic update on the next release
- [x] T014 `install.sh`: a retry of `open` after -600 right after `pkill`, the install gets to the hook step. 2026-10-23: `./install.sh --claude-hook --app` on the owner's Mac — SecretBar from the new build is running
