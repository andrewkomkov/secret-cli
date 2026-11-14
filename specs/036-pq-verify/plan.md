# Implementation Plan: `touchid pq` проверяет значения до записи

**Spec**: `specs/036-pq-verify/spec.md`

## Technical Context

- `helper/store/main.swift`, `upgradePQ`: цикл `unseal` с контекстом `c` после `seal`, до
  `writeFile`. Ошибка — `VaultError.damaged`, `withStoreLock` выходит без записи.
- Цена: второе чтение каждого значения в Secure Enclave. Touch ID не спрашивается: контекст уже
  подтверждён.

## Constitution Check

- **I**: значения остаются в памяти helper.
- **II**: вопрос Touch ID один, как в 033.
- **IV**: тесты 033 проходят через новую проверку.
- **V**: поведение при успехе не меняется.

## Complexity Tracking

Нет отступлений.
