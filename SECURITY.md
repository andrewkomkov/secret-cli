# Security policy

`secret` keeps passwords, tokens and API keys. Please report a vulnerability privately.

## Report a vulnerability

Use [private vulnerability reporting](https://github.com/andrewkomkov/secret-cli/security/advisories/new)
on GitHub. Do not open a public issue for a vulnerability.

Include the version (`secret version`), the macOS version, the store (`secret touchid status`) and
the steps that show the problem. Do not send real secret values: use a test secret.

You get an answer within 7 days. A fix goes into a release by release-please. The advisory names
the fixed version.

## Supported versions

Only the latest release gets fixes.

## Scope

In scope:

- a value that leaves the store without Touch ID, outside of the grace time or a lease;
- a value in `argv`, a log, an error message or the output of a command that does not print values;
- a way around the masking of `secret run --mask` or around the Claude Code hook that is not in
  the list "What remains" in the [Security](README.md#security) section of the README;
- the cookie bridge daemon: a request that is not from loopback or has no valid token, but gets an
  answer;
- the release: a tarball that does not match its build provenance.

Out of scope: an attacker who already runs code as the owner and approves Touch ID, a jailbroken
or compromised macOS, and the limits that the README lists under "What remains".

## Verify a release

Each release tarball has a build provenance attestation:

```sh
gh attestation verify secret-X.Y.Z.tar.gz -R andrewkomkov/secret-cli
```
