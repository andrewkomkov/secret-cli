<!-- ste: E1.1 — заголовок задан шаблоном spec-kit -->
# Implementation Plan: Приложение в строке меню SecretBar

**Branch**: `012-menu-bar-app` | **Date**: 2026-10-07 | **Spec**: [spec.md](spec.md)

## Summary <!-- slop: заголовок задан шаблоном spec-kit -->

SwiftUI `MenuBarExtra` со стилем окна. Модель вызывает `secret` и helper через `Process` и
разбирает вывод. Состояние grace приложение опрашивает раз в 5 секунд командой `grace-status`:
она не запускает агента. Сборка — `xcodebuild`, подпись ad-hoc.

## Technical Context

**Language and version**: Swift 6.4 в режиме Swift 5, SwiftUI, macOS 14.

**Primary Dependencies**: SwiftUI, AppKit (`NSPasteboard` не нужен: буфер ведёт `secret copy`),
ServiceManagement (`SMAppService` для запуска при входе).

**Testing**: `SecretBar --selftest` в `tests/run.sh`. Проверка бинарника: нет `SecItem*`, нет
entitlements.

## Constitution Check

| Принцип | Как соблюдается |
|---|---|
| I | значения только через stdin `secret set` и `secret copy` |
| II | Touch ID спрашивает агент helper, как для команды |
| III | исключение 1.4.0: Xcode, подпись ad-hoc |
| IV | `--selftest`, проверка бинарника; интерфейс — ручная проверка |
| V | команды `secret` без изменений |

## Project Structure

```text
app/
├── SecretBar.xcodeproj/project.pbxproj
├── SecretBar/SecretBarApp.swift    # MenuBarExtra, значок
├── SecretBar/Model.swift           # вызовы secret, разбор, selftest
├── SecretBar/Views.swift           # вкладки, строки, формы
└── build.sh                        # xcodebuild, подпись ad-hoc
```
