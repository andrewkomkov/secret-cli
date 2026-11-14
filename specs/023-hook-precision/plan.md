# Implementation Plan: a hook without false positives

**Spec**: `specs/023-hook-precision/spec.md`

## Technical Context

`hooks/claude-pretooluse.sh`, perl.

- Heredoc: a line with `<<WORD`, `<<'WORD'`, `<<"WORD"` or `<<-WORD`. The program before `<<` is the first
  word of this part of the command. For `cat`, `tee`, `git`, the hook removes the lines up to the line `WORD`. For other
  programs, the body stays.
- Store helper: the command is split into parts at `;`, `&`, `|` and newline. The hook lets through a part with
  `secret-vault` if its first word is `codesign`, `ls`, `stat`, `file`,
  `shasum`, `xattr`, `spctl`, and it has no `$(` and no backquote.

## Constitution Check

- I: the hook still blocks the output of values. `cat` writes the heredoc body to a file as text,
  the shell does not run it.
- IV: checks `023:` in `tests/run.sh`.
- V: the commands do not change.

## Complexity Tracking

No deviations.
