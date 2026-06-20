# Privacy

CueShot is designed as a local-first capture utility.

## What CueShot Captures

CueShot captures the pixels you explicitly target after arming capture. Depending on the mode, that may be an Accessibility element, a containing window, a manual drag area, an estimated click selection, or a full display.

## Where Captures Go

- PNG history is stored locally under `~/Library/Application Support/CueShot/History`.
- Diagnostics are stored locally under `~/Library/Application Support/CueShot/Logs/events.log`.
- Clipboard fallback writes the captured PNG to your local clipboard.
- Codex handoff is attempted only when Codex is already frontmost.

## What CueShot Does Not Do

- It does not upload screenshots to a server.
- It does not run analytics or telemetry.
- It does not capture continuously in the background.
- It does not paste into arbitrary apps in the background.

## Permissions

CueShot requests:

- Accessibility, to identify target bounds and perform local paste automation when requested.
- Screen Recording, to capture visible pixels.

You can revoke either permission at any time in macOS System Settings.
