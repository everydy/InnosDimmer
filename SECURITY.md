# Security Policy

## Supported Version

This repository tracks the current `main` branch only. There are no packaged public releases yet.

## Reporting a Vulnerability

Do not open a public issue for vulnerabilities or for diagnostics that include private local data.

Preferred reporting path:

1. Use GitHub's private vulnerability reporting or security advisory flow for this repository when available.
2. If that is unavailable, open a minimal public issue that says a private security report is needed, without including exploit details, logs, local paths, display identifiers, or crash dumps.

## Sensitive Data Guidelines

Avoid sharing:

- local usernames or filesystem paths
- display serial numbers or persistent display identifiers
- exported diagnostics that include machine-specific state
- crash logs with environment details
- screenshots that expose private desktop content

## Scope

In scope:

- unsafe handling of diagnostics export data
- persistence bugs that expose private machine or display state
- shortcut registration behavior that could trigger unintended commands
- failures to restore gamma tables after blue-reduction changes

Out of scope:

- requests to add hardware DDC/CI control
- behavior caused by unsupported macOS versions
- physical access attacks on the local machine
- issues requiring modified local builds with arbitrary code changes
