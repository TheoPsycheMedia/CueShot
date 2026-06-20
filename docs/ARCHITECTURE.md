# CueShot Architecture

CueShot is a native macOS app built with SwiftUI, AppKit interop, Accessibility, and ScreenCaptureKit.

## Capture Loop

The product loop is intentionally explicit:

1. User opens CueShot from the menu bar.
2. CueShot shows the floating capture control.
3. User chooses a mode and arms capture.
4. The next click or drag resolves a target.
5. CueShot captures pixels, writes PNG history, and copies or hands off the image.

This avoids the feeling that the app is silently watching the screen.

## Main Components

- `AppModel`: central state for mode, permissions, history, capture flow, and settings.
- `MenuBarActivationController`: AppKit menu bar item that reveals the floating capture control.
- `CapturePuckController`: floating control host for arming and stopping capture.
- `OverlayWindowController`: visual targeting and drag-region overlay.
- `GlobalGestureMonitor`: event monitor and optional global gesture handling.
- `AXHitTestService`: Accessibility hit testing for exact element and window bounds.
- `CaptureService`: ScreenCaptureKit image capture and PNG encoding.
- `CaptureHistoryStore`: local history records and filesystem storage.
- `CodexHandoffService`: clipboard fallback and Codex-frontmost paste handoff.
- `PermissionService`: macOS Accessibility and Screen Recording status checks.
- `DiagnosticsLogger`: local event log for troubleshooting.

## Accuracy Model

Element and Window modes are exact when the target app exposes useful Accessibility geometry. When Accessibility metadata is unavailable or too coarse, CueShot falls back to honest estimated capture modes rather than pretending the result is exact.

## Privacy Model

Captures, logs, and history stay local. There is no default upload path, analytics SDK, or remote telemetry.
