# Implementation Plan: Записи, которые читает только helper

**Branch**: `007-protected-items` | **Date**: 2026-10-02 | **Spec**: [spec.md](spec.md) | **Research**: [research.md](research.md)

## Summary <!-- slop: заголовок задан шаблоном spec-kit -->

В защищённом режиме helper — единственный читатель значений. Режим определяет наличие записи
`__secret-cli.policy`. В защищённом режиме `bin/secret` вызывает `secret-auth read/write/delete`,
в обычном — `security`, как сейчас.

Helper (Swift, legacy Keychain API): поиск `SecKeychainFindGenericPassword`, создание
`SecKeychainAddGenericPassword`, атрибуты `SecKeychainItemModifyAttributesAndData`, удаление
`SecKeychainItemDelete`. Проверка «запись моя»: чтение данных с выключенным UI удаётся только
создателю.

Touch ID: `LAContext.evaluatePolicy(.deviceOwnerAuthentication)`. Grace: файл с временем и
HMAC-SHA256 (`CryptoKit`) ключом из политики. Если политики нет или её нельзя прочитать, grace 0.

Перенос (`touchid on`, обновление helper): значения идут через pipe между процессами, на диск
не пишутся. Порядок для каждой записи: создать `NAME#new` → проверить чтение → удалить старую →
переименовать `NAME#new` в `NAME` (атрибут `svce`).

## Technical Context

**Language and version**: Swift 5 mode, bash 3.2

**Primary Dependencies**: Security (legacy API, deprecated), LocalAuthentication, CryptoKit

**Testing**: тестовая сборка helper `-D SECRET_TEST` во временном каталоге; вторая тестовая
сборка с другим кодом — для переноса и для отказа чужому бинарнику

## Constitution Check

| Принцип | Как соблюдается |
|---|---|
| I | значения между helper и bash идут через pipe; при переносе на диск не пишутся |
| II | Touch ID внутри helper; выключение — с Touch ID |
| III | helper из исходника в репе, `swiftc` и `codesign` из Command Line Tools |
| IV | тестовая сборка helper на временном keychain; настоящий Touch ID и окно `security` — ручная проверка |
| V | `touchid off` и режим без helper работают как раньше |

## Complexity Tracking

| Отступление | Причина |
|---|---|
| `touchid on` меняет способ хранения всех записей (принцип V) | иначе Touch ID обходится вызовом `security` |
| Тестовый helper отличается от рабочего (`-D SECRET_TEST`) | Touch ID нельзя нажать в тесте, а обход Touch ID не должен попасть в рабочий бинарник |
