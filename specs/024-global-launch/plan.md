# Implementation Plan: launch on the international market

**Spec**: `specs/024-global-launch/spec.md`

## Technical Context

- SecretBar: `developmentRegion = en`, `knownRegions = (en, ru, Base)`. The strings in the code are English.
  `Text`, `Button`, `Label` are translated automatically (LocalizedStringKey). Strings of type `String` (toasts,
  status, notifications) go through `String(localized:)`. The `ru` translation is in `Localizable.xcstrings`.
  The App Shortcuts phrases stay in the code in two languages. The keys are compared with the `.stringsdata` of the build.
- The label of a project without a prefix is `Parse.other` instead of the string "Other".
- `bin/secret`: `VERSION="1.1.0" # x-release-please-version`, the commands `version`, `--version`.
- release-please: `release-please-config.json` (`release-type: simple`,
  `include-component-in-tag: false`, `extra-files: [bin/secret]`), `.release-please-manifest.json`
  `1.1.0`, `bootstrap-sha` is the last commit of 1.1.0. There are no GitHub Releases for 1.0.0 and 1.1.0,
  release-please counts from `bootstrap-sha`.
- A tag from `GITHUB_TOKEN` does not start other workflows, so the formula is updated in the same
  workflow: job `formula` after `release_created`.
- Actions permissions in the repository: `default_workflow_permissions=write`,
  `can_approve_pull_request_reviews=true` (release-please needs it for the PR).
- Pages: `build_type=workflow`, `actions/deploy-pages`.
- Landing page: `site/index.html`, `site/style.css`, `site/main.js`, `site/img/`. Fonts: system fonts and
  JetBrains Mono from Google Fonts. Screenshots: `SecretBar --snapshot` in English.

## Constitution Check

- I, II: do not change. CI works on a temporary keychain, there are no values.
- III: Actions, release-please, Pages are the infrastructure of the repository, not a dependency of the command.
- IV: `tests/run.sh` is the same, now also in CI.
- V: the commands do not change, `version` is a new command. The SecretBar language follows the system language.

## Complexity Tracking

| Deviation | Reason |
|---|---|
| The SecretBar interface is in English when the system language is not Russian | International market, request of the owner |
| release-please sets the version and the tag, not the owner by hand | Request of the owner |
