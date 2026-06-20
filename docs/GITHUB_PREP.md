# CueShot GitHub Prep

## Repository Pitch

CueShot is a tiny macOS utility for capturing the exact UI detail you want to show Codex. Use the menu bar icon to reveal the floating capture control, arm the next click or drag, then send the resulting PNG to Codex or keep it in local history with clipboard fallback.

## Suggested GitHub Description

Tiny macOS capture utility for dropping exact UI screenshots into Codex.

## Suggested Topics

`macos`, `swiftui`, `screencapturekit`, `accessibility`, `codex`, `productivity`, `screenshots`

## Promo Assets

- README screenshot/poster: `docs/media/cueshot-promo-poster.png`
- GitHub landing page demo video: `docs/media/cueshot-promo-demo.mp4`
- Optional animated preview: `docs/media/cueshot-promo-preview.gif`
- Editable HyperFrames source: `marketing/cueshot-promo-demo/`

Raw generated audio and proof renders are intentionally ignored from source control. The public repo keeps the final media assets plus the editable source composition and regeneration notes.

## Completed GitHub Prep

- GitHub-ready README with the promo poster and demo video at the top
- MIT license
- Contributor guide
- Code of conduct
- Security policy
- Privacy statement
- Support notes
- GitHub issue templates and PR template
- GitHub Actions CI for `swift test`
- Release and architecture documentation
- Third-party notices

## Before Public Release

- Confirm all demo frames remain privacy-safe and free of real desktop source material
- Decide whether the Command triple-click listener remains optional, hidden behind settings, or removed from public positioning
- Add signing and notarization automation before distributing `.dmg` or `.pkg` artifacts
