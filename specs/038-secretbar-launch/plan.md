# Plan: SecretBar launch

## Order

1. Org. Create `secretbar` in the web form `github.com/account/organizations/new?plan=free`.
   Use curl with the jar `GITHUB_WEB_SESSION_JAR` inside `secret run --cookie-jar`. Read the
   `authenticity_token` and the fields from the form. Do not print the cookies.
   Result 2026-11-14: GitHub gave 403 "Access is temporarily restricted" to curl and to headless
   Chrome with the jar. The owner made the org in Safari.
2. Org settings with `gh api`: deploy keys on, release-please may approve pull requests, private
   vulnerability reporting, the ruleset of `main`.
3. Transfer `andrewkomkov/secret-cli` to `secretbar`, rename it to `secretbar`. Transfer
   `andrewkomkov/homebrew-secret` to `secretbar`, rename it to `homebrew-tap`.
4. In the tap: formula `secretbar.rb`, `formula_renames.json`, new URLs. In this repo: new links, new
   tap target in `release.yml`.
5. Landing repo `secretbar/secretbar.github.io`. Use the build of getgantry.github.io:
   `templates/`, `i18n/<lang>.json`, `build_pages.py`, sitemap, `llms.txt`, JSON-LD.
   Remove `site/` and `pages.yml` from this repo. Move the README images to `docs/img/`.
6. Gallery images: screenshots of SecretBar and of the terminal with `screencapture -l`. Fictional
   demo secrets only (`SHOP_DB_PASSWORD`, `BILLING_SMTP_PASS`).
7. Product Hunt through the MCP `producthunt`: `get_launch_context`, `start_launch`,
   `update_launch`, `prepare_launch_asset`. Show the text to the owner. After yes: `submit_launch`
   with `launchDate` 2026-11-16.

## Risks

- GitHub can ask for a sudo password or 2FA in the form. Then the owner does step 1 in Safari.
- The tap already uses a deploy key (`HOMEBREW_TAP_DEPLOY_KEY`, 028). The key moved with the tap.
  The org must allow deploy keys.
- Product Hunt requires an account that can launch. `get_launch_context` shows it.

## Complexity Tracking

- Principle V: the repo and the formula get new names. The command, the account, the paths and the
  reference format do not change. GitHub redirects keep old URLs working, and `formula_renames.json`
  moves an install of `secret` to `secretbar`.
