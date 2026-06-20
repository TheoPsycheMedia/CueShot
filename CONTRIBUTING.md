# Contributing to CueShot

Thanks for helping make CueShot better. The project is intentionally small: a focused macOS utility for exact screenshot capture and fast Codex handoff.

## Good First Contributions

- Fix a reproducible capture bug.
- Improve permission, onboarding, or error-state clarity.
- Add tests around capture mode selection, gesture state, or history behavior.
- Improve documentation for setup, release, or troubleshooting.
- Refine app accessibility without making capture activation ambiguous.

## Local Setup

```bash
git clone https://github.com/TheoPsycheMedia/CueShot.git
cd CueShot
swift test
./script/build_and_run.sh --verify
```

If you fork under a different remote, replace the clone URL with your fork.

## Development Notes

- Keep the capture loop explicit: menu bar icon, floating control, Arm, then click or drag.
- Do not introduce silent background capture behavior.
- Prefer native macOS and SwiftUI APIs before adding dependencies.
- Keep capture history local by default.
- Treat Accessibility and Screen Recording permissions as sensitive user trust surfaces.

## Pull Requests

1. Open an issue or discussion for large behavior changes before implementing.
2. Keep PRs focused on one product or engineering change.
3. Add or update tests when behavior changes.
4. Run `swift test` before opening the PR.
5. Include screenshots or a short screen recording for visible UI changes.

## Commit Style

Use plain, descriptive commit messages:

```text
Add floating capture control settings
Fix element hit-test fallback bounds
Document release packaging flow
```

## Security

Do not open public issues for vulnerabilities or privacy-sensitive capture behavior. Follow [SECURITY.md](SECURITY.md).
