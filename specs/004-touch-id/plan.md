# Implementation Plan: Touch ID

**Branch**: `004-touch-id` | **Date**: 2026-10-02 | **Spec**: [spec.md](spec.md)

## Summary <!-- slop: заголовок задан шаблоном spec-kit -->

Helper на Swift, две команды: `auth` и `status`. `bin/secret` находит его в `build/` рядом с
собой (через symlink). `require_auth` вызывается в `get`, `copy`, `run` (после чтения ссылок, до
запуска команды) и `export`. Причина в окне — операция и имена секретов. Подмены для тестов
разрешены, только если inode keychain (`stat -L -f %d:%i`) не совпадает с keychain по умолчанию.

## Technical Context

**Language and version**: Swift 5 mode (`swiftc -swift-version 5`), bash 3.2

**Primary Dependencies**: LocalAuthentication, Security (`SecKeychainGetStatus` устарел, но работает в macOS 27)

## Constitution Check

| Принцип | Как соблюдается |
|---|---|
| II | подтверждение делает человек; выключение тоже требует подтверждения |
| III | helper — исходник в репе, сборка `swiftc` из Command Line Tools |
| IV | заглушка helper в тестах; настоящий Touch ID — ручная проверка |
| V | по умолчанию `touchid off`, команды работают как раньше |

## Complexity Tracking

| Отступление | Причина |
|---|---|
| При `touchid on` без helper команда не работает (принцип III говорит, что без helper команда работает без его возможностей) | иначе удаление `build/secret-auth` выключало бы Touch ID без подтверждения. При `touchid off` команда без helper работает |
