# Implementation Plan: SecretBar — «Новый секрет…» в меню и ссылка после создания

**Spec**: `specs/019-secretbar-new-secret-link/spec.md`

## Technical Context

SwiftUI, `app/SecretBar`. Изменения только в приложении.

- `Navigation.newSecret()`: счётчик `addRequests` и `showMain()`. Главное окно следит за
  счётчиком и ставит `sheet = .add`, если другой лист не открыт.
- `Views.swift`: пункт «Новый секрет…» в меню «…».
- `EditorSheet.save()`: после успешного `add` или `generate` вызывает
  `Store.copyReference(name, saved: true)`. Тост объединяет «сохранён» и «ссылка в буфере».

## Constitution Check

- I: в буфер идёт имя, значение приложение не видит.
- III: только системные фреймворки.
- IV: окна и буфер проверяются руками, запись в `tasks.md` с датой; `tests/run.sh` проходит.
- V: команды `secret` и формат ссылки не меняются.

## Complexity Tracking

Нет отступлений.
