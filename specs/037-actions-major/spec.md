# Feature Specification: мажорные версии actions

**Feature Branch**: `037-actions-major`

**Created**: 2026-11-14

**Status**: Done 2026-11-14

**Input**: PR #15 от Dependabot. Владелец: «да - давай».

## Цель

Перейти на новые мажорные версии пяти actions. Workflow работают как раньше.

| Action | Было | Стало |
|---|---|---|
| actions/checkout | 4.4.0 | 7.0.1 |
| actions/configure-pages | 5.0.0 | 6.0.0 |
| actions/upload-pages-artifact | 3.0.1 | 5.0.0 |
| actions/deploy-pages | 4.0.5 | 5.0.1 |
| googleapis/release-please-action | 4.4.1 | 5.0.0 |

## Ломающие изменения и проверка

- Все пять: Node 24. Runner GitHub его поддерживает.
- checkout 7: не делает checkout PR из форка для `pull_request_target` и `workflow_run`. У нас
  этих триггеров нет.
- upload-pages-artifact 4: не кладёт dotfiles в артефакт. В `site/` dotfiles нет.
- release-please-action 5: только Node 24 и release-please 17.6.0. Входы `config-file` и
  `manifest-file` не изменились.

## Requirements

- **FR-001**: каждая action закреплена SHA, SHA совпадает с тегом в репозитории action.
- **FR-002**: `persist-credentials: false` и права jobs не меняются.

## Success Criteria

- **SC-001**: CI PR #15 проходит на macos-15 и macos-26.
- **SC-002**: после merge `release.yml` и `pages.yml` на `main` проходят.
