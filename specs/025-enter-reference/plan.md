# Implementation Plan: Enter копирует ссылку, новый секрет из панели

**Spec**: `specs/025-enter-reference/spec.md`

## Technical Context

- `Store.pick(_ name:, value:)`: `copy` или `copyReference`. Признак ⇧: `KeyPress.modifiers` в
  `onKeyPress(.return)`, в `onSubmit` и в клике — `NSEvent.modifierFlags`.
- Быстрая панель: `onKeyPress(.return)` на поле, `onSubmit` — запасной путь.
- Панель строки меню: кнопка `plus` в шапке, `⌘N`, строка «Создать NAME» при пустом результате.
- Главное окно: `onKeyPress(.return)` списка смотрит на ⇧.
- `Navigation.newSecret(name:)` кладёт имя в `addName`; `EditorSheet` берёт его при появлении.

## Constitution Check

- I: ссылка — имя, не значение. Значение по-прежнему кладёт в буфер только helper.
- II: ⇧↩ спрашивает Touch ID, как раньше ↩.
- IV: `--selftest` проверяет выбор действия и имя из запроса.
- V: смена клавиши ↩ — отступление, см. ниже.

## Complexity Tracking

| Отступление | Причина |
|---|---|
| ↩ копирует ссылку вместо значения | Просьба владельца. Значение — ⇧↩ |
