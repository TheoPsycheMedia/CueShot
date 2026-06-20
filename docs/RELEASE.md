# Release Guide

CueShot can be built locally today. Public notarized distribution still requires Apple Developer signing credentials.

## Local Install

```bash
./script/build_and_run.sh --install
```

The script builds the SwiftPM executable, creates a `.app` bundle under `dist/`, signs it with the first available Apple Development identity or ad-hoc signing, then copies it to `~/Applications/CueShot.app`.

## Verification Before Tagging

```bash
swift test
./script/build_and_run.sh --verify
swift script/smoke_global_capture.swift
swift script/smoke_area_capture.swift
```

Smoke scripts require Accessibility and Screen Recording permission for the built app bundle.

Native macOS 26 Liquid Glass symbols are gated behind the `CUESHOT_ENABLE_NATIVE_LIQUID_GLASS` compile flag so public GitHub runners and older SDKs can compile the material fallback path.

## GitHub Release Checklist

1. Confirm `swift test` passes locally and in GitHub Actions.
2. Build with `./script/build_and_run.sh --install`.
3. Verify first-run onboarding, menu bar activation, floating capture control, and Settings.
4. Confirm no private screenshots or local personal data are included in release media.
5. Tag the release.
6. Attach the final app artifact once signing/notarization is ready.

## Notarization Status

The current repository is source-ready, but not yet notarization-ready. A public signed `.dmg` or `.pkg` release should add:

- Developer ID Application signing.
- Hardened Runtime entitlements.
- Notarization upload and stapling.
- A repeatable release artifact script.
