# Feature Specification: Leak protection during agent work

**Feature Branch**: `001-agent-safety` (the work is done in `main` of the local repo)

**Created**: 2026-10-02

**Status**: Done — 2026-10-02

**Input**: The owner wants the agent to create secrets without seeing the values. Values must
not get into command output. It must be visible which secrets the agent took. The ban on
reading values must rest on more than a rule in `CLAUDE.md`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The agent creates a password without seeing it (Priority: P1)

The agent needs a new password, for example for a DB account. It runs one command. The
password appears in the keychain, and the output has only the name and the length.

**Independent Test**: `secret gen -l 24 NAME` — the keychain has an item of length 24, the output has no value.

**Acceptance Scenarios**:

1. **Given** NAME does not exist, **When** `secret gen NAME`, **Then** the keychain has an item of 32 characters
   `A-Za-z0-9`, the output is `generated: NAME (32 chars)`.
2. **Given** NAME exists, **When** `secret gen NAME`, **Then** an error, the old value stays.
   With `-f` the value is replaced.
3. **When** `secret gen -s symbols NAME`, **Then** the value also has the characters
   `!#%+-.=@^_~`, but no quotes, `\`, `$`, `` ` `` or space.

### User Story 2 - Values do not get into the output (Priority: P1)

The agent runs a command with secrets. If the command prints a value (`curl -v`, debugging),
the output has `***` in its place.

**Independent Test**: `secret run --mask NAME -- sh -c 'echo "$NAME"; echo "$NAME" >&2'` prints
`***` to stdout and to stderr.

**Acceptance Scenarios**:

1. **Given** `--mask`, **When** the command prints a value to stdout or stderr, **Then** it shows `***`.
2. **Given** `--mask`, **When** the command exits with code N, **Then** `secret run` exits with code N.
3. **Given** `SECRET_RUN_MASK=1`, **When** `secret run` without the flag, **Then** masking is on.
4. **Given** `--mask` and `-e .env`, **Then** the values from `secret:` references are masked, and plain
   `.env` values (ports, hosts) are not masked.

### User Story 3 - It is visible which secrets were taken (Priority: P2)

The owner sees when and which secrets were read, and who read them: a human or the agent.

**Independent Test**: after `secret get A` and `secret run B -- true`, the command `secret log`
shows two lines with the time, the command, the name and the source; the log has no values.

**Acceptance Scenarios**:

1. **When** `get`, `run`, `copy`, `export` read a secret, **Then** a line goes into the log:
   time, command, names, `agent` or `human`, parent process.
2. **Given** `SECRET_LOG=off`, **Then** the log is not written.
3. **When** `secret log -n 5 NAME`, **Then** the last 5 lines about NAME.

### User Story 4 - The agent cannot read values around the rules (Priority: P2)

A Claude Code hook stops commands that print values: `secret get`,
`security find-generic-password -w`/`-g`, `security dump-keychain -d`, printing `.env` with
`cat`/`less`/`head`/`tail`/`bat`, printing the environment inside `secret run` (`env`, `printenv`, `set`).

**Independent Test**: the hook gets JSON with such a command as input — exit code 2 and the reason in
stderr. A normal command (`secret run X -- psql`) — code 0.

### Edge Cases

- A secret value occurs inside another value: the longer one is masked first.
- A command under `--mask` prints without a newline (progress): the output appears line by line.
- The log cannot be written: the command works, a warning goes to stderr.
- The hook gets JSON without the `command` field: it lets it pass.

## Requirements *(mandatory)*

- **FR-001**: `secret gen [-c COMMENT] [-l LEN] [-s alnum|symbols|hex] [-f] NAME`. LEN from 8 to 256, default 32.
- **FR-002**: The `gen` value comes from `/dev/urandom` and is not printed.
- **FR-003**: `secret run --mask` replaces secret values with `***` in the stdout and stderr of the command and keeps its exit code.
- **FR-004**: `SECRET_RUN_MASK=1` turns on `--mask` by default.
- **FR-005**: The log is `${SECRET_LOG:-~/.local/state/secret/access.log}`, mode 600, no values.
- **FR-006**: `secret log [-n N] [NAME]` prints the log.
- **FR-007**: The hook `hooks/claude-pretooluse.sh` for the PreToolUse event of the Bash tool; `install.sh --claude-hook` adds it to `~/.claude/settings.json`.

## Success Criteria *(mandatory)*

- **SC-001**: The output of `gen`, `run --mask`, `log` and the log file have no secret value at all (checked by a test).
- **SC-002**: The hook blocks all 8 patterns from US4 and lets the 5 normal commands from the test pass.
- **SC-003**: `tests/run.sh` passes in full.

## Assumptions

- Masking catches the value as is. An encoded value (base64 in `Authorization: Basic`,
  URL encoding) is not caught: this is written in the README.
- The hook protects against an agent mistake, not against malice: a command can be written so
  that the pattern does not recognize it.
- `CLAUDECODE=1` in the environment means a run from Claude Code.
