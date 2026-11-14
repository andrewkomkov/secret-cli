# Plan: мажорные версии actions

1. Проверьте SHA из PR #15 через `gh api repos/OWNER/ACTION/commits/TAG`.
2. Прочитайте release notes каждой мажорной версии. Сравните их с триггерами и `site/`.
3. Добавьте эту спеку в ветку PR #15. Сделайте merge через rebase.
4. Проверьте запуски `release.yml` и `pages.yml` на `main`.
