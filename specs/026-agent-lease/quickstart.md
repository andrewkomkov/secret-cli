# Quickstart: проверка аренды

## Автотесты

```bash
tests/run.sh
```

Проверки 026 в тестовой сборке: аренда после `test-lock`, `not leased` для другого имени,
`test-sleep`, конец по `SECRET_TEST_MAX_LEASE`, `--revoke`, `lock`, `set` убирает имя,
`--for 25h`, отказ Touch ID.

## Ручная проверка (SC-005, SC-006)

1. `secret ls -l` — выбрать два имени, A и B.
2. `secret lease --for 1h A`. Окно Touch ID называет A и 1h. Дать Touch ID.
3. `secret lease status` — A и время конца.
4. Заблокируйте экран. Через минуту запустите из задачи по расписанию или по ssh:
   - `secret run --mask A -- sh -c 'test -n "$A" && echo ok'` — `ok`.
   - `secret run --mask B -- true` — сразу `not leased: B`.
5. Переведите Mac в сон на 5 минут. Повторите шаг 4 для A — `ok`.
6. Запустите `secret lease --revoke`. Повторите шаг 4 для A — `not leased: A`.
7. SecretBar: при активной аренде строка аренды видна, кнопка отзыва работает.
