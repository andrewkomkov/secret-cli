# Implementation Plan: search for a secret by meaning with the on-device model

**Spec**: `specs/034-fm-ask/spec.md`

## Technical Context

### bin/secret, `cmd_ls`

- New parse of the flag `--ask QUERY` (together with `-l`).
- List: the same path as `ls -l` (name, expiry, comment), without values and without Touch ID.
- Path to `fm`: `test_override SECRET_FM /usr/bin/fm`. The test override works only with the
  test keychain, as the other `SECRET_*` overrides.
- Checks before the call: `fm` exists and is executable, otherwise code 2 and the advice
  `secret ls -l | grep -i WORD`.
- Parts of 40 lines. For each part:
  - the JSON schema goes to a temporary file (mode 600, `mktemp`, a `trap` deletes it): an object
    with the array `names`, `items.enum` is the names of the part;
  - the text goes to the stdin of `fm respond -m system -g --no-stream --schema FILE -i
    INSTRUCTIONS`: lines `NAME: comment` and the line `Query: QUERY`;
  - the answer is JSON. `perl` takes the names from the answer (JSON::PP is in the system perl).
    The command keeps only the names from the part.
- `fm` error (license, Apple Intelligence off, model not available): the first line of the `fm`
  stderr without colours, code 2 and the advice.
- `-l`: for the found names, prints the `ls -l` lines in the order of the answer.
- Code 1 if nothing is found.

### Tests (tests/run.sh)

A stub `fm` in `$TMP`: writes its arguments and stdin to a file, answers with a given JSON.

- the names from the answer are printed, the order of the answer is kept;
- a name not from the list is dropped;
- `{"names":[]}` — code 1, empty output;
- no stub — code 2 and the advice;
- the stub saw `-m system`, but did not see any value;
- `-l` prints a line with the comment;
- 45 secrets — two calls of the stub.

## Constitution Check

- **I**: the values are not read. Only names and comments go to `fm`.
- **II**: Touch ID is not needed: the command does not read values.
- **III**: `/usr/bin/fm` is in macOS 27. Without it, the command reports the cause; the rest works
  as before. `perl` and `JSON::PP` are system ones.
- **IV**: tests with a stub `fm`, without the model.
- **V**: new flag `--ask`; the old behaviour of `ls` does not change.

## Complexity Tracking

| Deviation | Reason |
|---|---|
| The command calls a model | Only `-m system`, the model on the device, without network. Names and comments are already not secret for `ls -l`. |
