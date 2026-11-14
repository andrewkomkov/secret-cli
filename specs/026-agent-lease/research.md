# Research: Secret lease for agents

## R1. Where to hold the lease

- **Decision**: in the agent process `secret-vault agent`, next to the grace cache.
- **Rationale**: the agent memory is already closed by the hardened runtime (principle II). The
  agent socket already checks `getpeereid`. A second process would mean a second socket and a
  second point of attack.
- **Alternatives considered**:
  - A file with encrypted values. The key of this file must be kept without Touch ID. That is a
    store without protection.
  - A separate lease process. More code, the same protection.

## R2. Read while the screen is locked

- **Decision**: the agent reads the lease values at the moment of Touch ID and keeps them in
  memory. After a screen lock, the agent no longer needs the Secure Enclave key.
- **Rationale**: a Secure Enclave key with `WhenUnlockedThisDeviceOnly` and `.userPresence`
  refuses on a locked Mac. Nobody sees a Touch ID window on a locked screen.
- **Alternatives considered**:
  - A key without `.userPresence` for agent secrets. This breaks principle II.
  - Confirmation from a phone. The Secure Enclave key still refuses during a lock.

## R3. What the agent sees during a screen lock

- **Decision**: the agent checks `screenLocked()` on each `read`. If the screen is locked and
  the name is not in the lease, the agent at once answers `err 6 not leased: A, B` and skips
  `confirmedContext`.
- **Rationale**: now the command waits for a window that nobody sees.

## R4. Change of a secret during the lease

- **Decision**: the lease table keeps the permanent reference `r` of the record next to the
  value. On read, the agent compares it with the file. If the reference is different or the
  record is gone, the name leaves the lease.
- **Rationale**: the grace cache already works this way (010 R11). The agent can read a new
  value only after Touch ID. The old value must not be given.

## R5. Several leases

- **Decision**: leases add up. Each name has its own end; for a repeated name, the later end.
- **Rationale**: two agents in two projects request different sets. If a new lease replaced the
  old one, the first agent would lose its secrets.

## R6. Mark in the log

- **Decision**: the agent answer to `read` gets a third field: for each name `l` (lease)
  or `g` (grace or Touch ID). `secret-vault read` writes it to stderr as the line
  `source: l,g`. `bin/secret` writes the detail `lease` to the log for leased names.
- **Rationale**: the protocol between `bin/secret` and the helper is internal; both sides are in
  the repo.

## R7. Lock test

- **Decision**: in the test build, `screenLocked()` reads an agent flag. `test-lock` sets the
  flag and ends grace, `test-unlock` clears the flag, `test-sleep` ends grace like a sleep.
- **Rationale**: principle IV: the test passes without windows and with an unlocked screen.
