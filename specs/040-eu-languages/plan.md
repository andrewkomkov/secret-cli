# Plan: European languages

1. Translate the catalog `Localizable.xcstrings` (state `translated`) for the six languages.
2. Add the regions to `knownRegions`.
3. Make `_locales/<lang>/messages.json` for the extension from `en`.
4. Add a check to `tests/run.sh`: each language exists for each key, and format arguments match.
5. Build SecretBar with `app/build.sh` (DerivedData on the external drive).
6. Change the language rule in `CLAUDE.md` and in the constitution (with feature 039).
