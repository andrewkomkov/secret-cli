# Implementation Plan: Меньше вызовов keychain

**Branch**: `008-fewer-keychain-calls` | **Date**: 2026-10-02 | **Spec**: [spec.md](spec.md)

## Summary <!-- slop: заголовок задан шаблоном spec-kit -->

Переменная `ITEMS` хранит вывод `list_items` (TSV: имя, комментарий, срок). Её заполняет первый
вызов `items_cached`, а сбрасывает каждая запись и удаление. `item_known`, `get_comment`,
`get_expiry` читают из неё через `awk`. Переменная `BATCH=1` откладывает `refresh_names` до
конца пакетной команды. В `set` проверка после записи — прямой `security find-generic-password`.

## Constitution Check

| Принцип | Как соблюдается |
|---|---|
| I | в кэше только атрибуты, значений нет |
| V | вывод команд не меняется |

## Complexity Tracking

Отступлений нет.
