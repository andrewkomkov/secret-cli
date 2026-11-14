# Feature Specification: English repository

**Feature Branch**: `039-english-repo`

**Created**: 2026-11-14

**Status**: Done 2026-11-14

**Input**: Owner, 2026-11-14: "rewrite the whole repo in English".

## Goal

A visitor from Product Hunt reads every file of the repository in English. Russian stays only
where it is a translation for users: `README.ru.md`, `ru` in the string catalogs, and Russian
words in code that handle Russian input.

## Scope

- `specs/001-*` to `specs/037-*`: `spec.md`, `plan.md`, `tasks.md` and other files. Translate the
  meaning. Keep the structure, the IDs (FR, SC, T), the ticks, the dates, the code and the names.
- `.specify/memory/constitution.md`: translate. New version 3.0.0, because the language rule
  changes.
- `CLAUDE.md`: specs and the constitution are in English.
- Comments and test data in Russian in `tests/`, `helper/`, `install.sh`: translate if they are
  not Russian input on purpose.

## Out of scope

- `README.ru.md` and the `ru` strings (translations for users).
- Russian test data that checks Russian input (keyboard layout, Cyrillic names).
- Git history.

## Requirements

- **FR-001**: no Cyrillic in `specs/` and in the constitution.
- **FR-002**: a translated tick stays a tick. A translated task keeps its date.
- **FR-003**: `tests/run.sh` passes.

## Success Criteria

- **SC-001**: `git grep -lI '[А-Яа-яЁё]'` shows only the files of "Out of scope".
