# Plan: major versions of actions

1. Check the SHA from PR #15 with `gh api repos/OWNER/ACTION/commits/TAG`.
2. Read the release notes of each major version. Compare them with the triggers and `site/`.
3. Add this spec to the branch of PR #15. Merge with rebase.
4. Check the runs of `release.yml` and `pages.yml` on `main`.
