# Research: SecretBar 2

| # | Check | Result |
|---|---|---|
| R15 | App Intents and Spotlight for SecretBar, 2026-10-07 | with an ad-hoc signature, `linkd` writes `sandbox_extension_issue_file failed … Operation not permitted` and `Bundle did not provide any metadata sources`, the same in `~/Applications` and in `/Applications`. With an Apple Development signature (Personal Team, no profile), `linkd` accepts the connection of the app |
| R16 | `--snapshot` images | `cacheDisplay` mixes the themes of the layers: in the dark theme, some areas are white. `layer.render(in:)` with the theme set before the first window gives the correct dark theme. The sidebar with the transparency effect does not go into the layer snapshot |
