# Feature Specification: SecretBar launch

**Feature Branch**: `038-secretbar-launch`

**Created**: 2026-11-14

**Status**: In progress

<!-- STE deviation: the input is a quote of the owner. -->
**Input**: Owner, 2026-11-14: "the software is good enough for Product Hunt. Move it to a separate
GitHub org, move the repo, make a landing on GitHub Pages, then schedule the launch for Monday on
https://mcp.producthunt.com/mcp. Do it like getgantry. You can rename the app too. Use the cookie
feature for Product Hunt and GitHub."

## Goal

The product has one name: SecretBar. It has its own GitHub org `secretbar`, a landing at
`https://secretbar.github.io`, and a Product Hunt launch on Monday 2026-11-16.

## Names

| Item | Before | After |
|---|---|---|
| GitHub org | user `andrewkomkov` | org `secretbar` |
| Repository | `andrewkomkov/secret-cli` | `secretbar/secretbar` |
| Homebrew tap | `andrewkomkov/homebrew-secret`, formula `secret` | `secretbar/homebrew-tap`, formula `secretbar` (`formula_renames.json`: `secret` → `secretbar`) |
| Landing | `andrewkomkov.github.io/secret-cli/` | `secretbar.github.io` (repo `secretbar/secretbar.github.io`) |
| Product Hunt | none | SecretBar |

These items do not change (constitution, principle V). They are the command `secret`, the keychain account
`secret-cli`, the paths `~/.local/share/secret` and `~/.local/state/secret`, the reference format
`secret:NAME`, the hook, and the rules in `docs/claude-md-secrets.md`.

## User Scenarios

### US1 - new home (P1)

1. `brew install secretbar/tap/secretbar` installs the command and the helpers.
2. Old URLs of the repo and of the tap open the new repo (GitHub transfer redirect).
3. `brew upgrade` of an old install of `andrewkomkov/secret/secret` continues to work.
4. A release in the new repo updates the formula in `secretbar/homebrew-tap`.

### US2 - landing (P1)

1. `https://secretbar.github.io` shows the product: what it does, install, agent safety, SecretBar,
   Safari cookies, post-quantum store, FAQ.
2. The landing is in English and in the languages of feature 040. A language switch and hreflang
   tags connect the pages.
3. SEO: sitemap with hreflang, `robots.txt`, `llms.txt`, JSON-LD SoftwareApplication and FAQ,
   Open Graph and Twitter cards.
4. The landing shows only released features.

### US3 - Product Hunt (P1)

1. Product Hunt shows the SecretBar launch on 2026-11-16 (midnight Pacific).
2. The launch has a name, tagline, description, topics, thumbnail, gallery, links (landing and
   GitHub) and a first maker comment.
3. The owner approves the text before submit. The owner can change it in the Product Hunt editor.

## Requirements

- **FR-001**: create the org `secretbar` with the web session of the owner from the jar
  `GITHUB_WEB_SESSION_JAR` (`secret run --cookie-jar`). The GitHub API cannot create an org for a
  user account. If GitHub blocks the automated session, the owner makes the org in the browser.
- **FR-002**: transfer the repo and the tap with `gh api repos/OWNER/REPO/transfer`, then rename
  them.
- **FR-003**: change every link `andrewkomkov/secret-cli`, `andrewkomkov/homebrew-secret` and
  `andrewkomkov.github.io/secret-cli` in the repo to the new names. `CHANGELOG.md` keeps the old
  compare links: GitHub redirects them.
- **FR-004**: the tap update in `release.yml` works in the org (deploy keys or token, org setting
  `deploy_keys_enabled_for_repositories`, `can_approve_pull_request_reviews` for release-please).
- **FR-005**: the old site in `site/` moves to the repo `secretbar/secretbar.github.io`. GitHub
  has no redirect for the old Pages URL `andrewkomkov.github.io/secret-cli/`, so it stops working.
- **FR-006**: Product Hunt goes through the MCP server `producthunt` (OAuth of the owner). The
  launch is submitted only after the owner says yes to the text.
- **FR-007**: no owner data in the public texts (CLAUDE.md, "What goes into the repository").

## Success Criteria

- **SC-001**: `gh repo view secretbar/secretbar` works. `git ls-remote` with the old URL works.
- **SC-002**: `brew install secretbar/tap/secretbar` and `brew test` pass in the tap CI.
- **SC-003**: the landing opens in each language. The link checker gives 0 broken links.
- **SC-004**: `get_launch` shows status scheduled with the date 2026-11-16.
