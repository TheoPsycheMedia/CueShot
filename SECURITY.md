# Security Policy

CueShot works near sensitive macOS surfaces: Accessibility, Screen Recording, clipboard contents, app focus, and local screenshot history. Please report vulnerabilities privately.

## Supported Versions

Until the first tagged release, security fixes target the `main` branch.

## Report a Vulnerability

Use GitHub's private vulnerability reporting or Security Advisory flow for this repository. If that is unavailable, contact a maintainer privately before opening a public issue.

Please include:

- macOS version.
- CueShot commit or release.
- Exact reproduction steps.
- Whether Accessibility or Screen Recording permission was granted.
- Logs only if they do not contain private screenshot names, local paths, or personal data.

## What Counts

- Capturing without an explicit user action.
- Capturing outside the selected target or mode.
- Unexpected clipboard writes.
- Unexpected paste automation into another app.
- Leaking capture history or diagnostics outside the local machine.
- Permission bypasses, crashes, or denial-of-service issues.

## Privacy Baseline

CueShot should stay local-first. It should not upload screenshots, telemetry, logs, or clipboard data by default.
