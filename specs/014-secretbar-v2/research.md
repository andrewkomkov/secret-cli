# Research: SecretBar 2

| # | Проверка | Результат |
|---|---|---|
| R15 | App Intents и Spotlight для SecretBar, 2026-10-07 | с подписью ad-hoc `linkd` пишет `sandbox_extension_issue_file failed … Operation not permitted` и `Bundle did not provide any metadata sources`, в `~/Applications` и в `/Applications` одинаково. С подписью Apple Development (Personal Team, без profile) `linkd` принимает соединение приложения |
| R16 | Снимки `--snapshot` | `cacheDisplay` смешивает темы слоёв: в тёмной теме часть областей белая. `layer.render(in:)` с темой, заданной до первого окна, даёт верную тёмную тему. Боковая панель с эффектом прозрачности в снимок слоёв не попадает |
