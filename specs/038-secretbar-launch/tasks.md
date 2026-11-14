# Tasks: SecretBar launch

## Org and transfer

- [x] T001 Org `secretbar` exists
- [x] T002 Org settings: deploy keys, pull request approval for actions, vulnerability reporting
- [x] T003 Repo is `secretbar/secretbar`. Old URL redirects
- [x] T004 Tap is `secretbar/homebrew-tap` with formula `secretbar` and `formula_renames.json` (`secret` → `secretbar`)
- [x] T005 Links in the repo point to the new names
- [ ] T006 `release.yml` updates the new tap. Ruleset of `main` is in place
- [x] T007 Tap CI passes: `brew install`, `brew test`, `brew audit --strict`

## Landing

- [ ] T008 Repo `secretbar/secretbar.github.io` with the build from templates and i18n
- [ ] T009 Pages for each language of feature 040, with hreflang and the language switch
- [ ] T010 SEO files: sitemap, robots, `llms.txt`, JSON-LD, OG image
- [ ] T011 Link check gives 0 broken links
- [x] T012 `site/` and `pages.yml` are removed from this repo. README images are in `docs/img/`

## Product Hunt

- [x] T013 MCP `producthunt` is signed in (`get_my_account`)
- [ ] T014 Thumbnail and gallery images
- [ ] T015 Draft launch with all fields
- [ ] T016 Owner approves the text
- [ ] T017 Launch is scheduled for 2026-11-16 (`get_launch`)
