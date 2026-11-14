# Tasks: SecretBar launch

## Org and transfer

- [x] T001 Org `secretbar` exists
- [x] T002 Org settings: deploy keys, pull request approval for actions, vulnerability reporting
- [x] T003 Repo is `secretbar/secretbar`. Old URL redirects
- [x] T004 Tap is `secretbar/homebrew-tap` with formula `secretbar` and `formula_renames.json` (`secret` → `secretbar`)
- [x] T005 Links in the repo point to the new names
- [x] T006 2026-11-14 `release.yml` updated the new tap for 1.9.0. The transfer emptied the ruleset bypass. It is set again as in 032 (Repository admin, `always`)
- [x] T007 Tap CI passes: `brew install`, `brew test`, `brew audit --strict`

## Landing

- [x] T008 Repo `secretbar/secretbar.github.io` with the build from templates and i18n
- [x] T009 Pages for each language of feature 040, with hreflang and the language switch
- [x] T010 SEO files: sitemap, robots, `llms.txt`, JSON-LD, OG image
- [x] T011 2026-11-14 `scripts/check_links.py`: 8 pages, 12 external links, 0 problems
- [x] T012 `site/` and `pages.yml` are removed from this repo. README images are in `docs/img/`

## Product Hunt

- [x] T013 MCP `producthunt` is signed in (`get_my_account`)
- [x] T014 Thumbnail and gallery images
- [x] T015 Draft launch with all fields
- [x] T016 2026-11-14 Owner approved the text and the shoutout for Claude Code
- [x] T017 2026-11-14 Launch 1316825 is scheduled for 2026-11-16 00:00 Pacific
