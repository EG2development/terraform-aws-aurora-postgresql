# Security policy

## Reporting a vulnerability

Report a vulnerability privately through this repository's **Security** tab, using
**Report a vulnerability** (GitHub private vulnerability reporting). Do not open a
public issue. The team in [`.github/CODEOWNERS`](.github/CODEOWNERS) acknowledges a
report within five working days.

A vulnerability here is a module default or behaviour that makes a caller's
infrastructure less secure than this README and
[the design decisions](docs/explanation/design-decisions.md) say it is.

## Supported versions

Fixes are released on the latest major version only. A security fix that changes a
secure default for existing callers ships as a major release with upgrade notes.
