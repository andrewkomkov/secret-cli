# Implementation Plan: хук без ложных срабатываний

**Spec**: `specs/023-hook-precision/spec.md`

## Technical Context

`hooks/claude-pretooluse.sh`, perl.

- Heredoc: строка с `<<WORD`, `<<'WORD'`, `<<"WORD"` или `<<-WORD`. Программа перед `<<` — первое
  слово этой части команды. Для `cat`, `tee`, `git` хук убирает строки до строки `WORD`. Для других
  программ тело остаётся.
- Helper хранилища: команда делится на части по `;`, `&`, `|`, переводу строки. Часть с
  `secret-vault` хук пропускает, если её первое слово — `codesign`, `ls`, `stat`, `file`,
  `shasum`, `xattr`, `spctl`, и в ней нет `$(` и обратной кавычки.

## Constitution Check

- I: хук по-прежнему блокирует вывод значений. `cat` пишет тело heredoc в файл как текст,
  shell его не запускает.
- IV: проверки `023:` в `tests/run.sh`.
- V: команды не меняются.

## Complexity Tracking

Нет отступлений.
