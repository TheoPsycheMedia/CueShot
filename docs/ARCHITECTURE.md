# CueShot Architecture

CueShot is a native macOS app built with SwiftUI, AppKit interop, Accessibility, and ScreenCaptureKit.

## Capture Loop

The product loop is intentionally explicit:

1. User opens CueShot from the menu bar.
2. CueShot shows the floating capture control.
3. User chooses a mode and arms capture.
4. The next click or drag resolves a target.
5. CueShot captures pixels, writes PNG history, copies the PNG and file URL to the clipboard, and keeps the floating preview visible for paste, drag, or reveal.

This avoids the feeling that the app is silently watching the screen.

## Main Components

- `AppModel`: central state for mode, permissions, history, capture flow, and settings.
- `MenuBarActivationController`: AppKit menu bar item that reveals the floating capture control.
- `CapturePuckController`: floating control host for arming, stopping capture, and previewing the latest clipboard PNG.
- `OverlayWindowController`: visual targeting and drag-region overlay.
- `GlobalGestureMonitor`: event monitor and optional global gesture handling.
- `AXHitTestService`: Accessibility hit testing for exact element and window bounds.
- `CaptureService`: capture planning, ScreenCaptureKit image capture, and PNG encoding.
- `CaptureHistoryStore`: local history records and filesystem storage.
- `CodexAppServerClient`: JSON-RPC client for `codex app-server` local-image turns.
- `CodexHandoffService`: clipboard-first handoff reporting, with optional experimental Codex App Server image delivery.
- `PermissionService`: macOS Accessibility and Screen Recording status checks.
- `DiagnosticsLogger`: local event log for troubleshooting.

## Accuracy Model

Element and Window modes are exact when the target app exposes useful Accessibility geometry. When Accessibility metadata is unavailable or too coarse, CueShot marks the target as adjusted, window fallback, or estimated rather than pretending the result is exact. Large container roles such as web areas, scroll areas, groups, and windows are treated as lower-confidence element targets when they cover most of the display.

## Clipboard Handoff Model

CueShot treats the clipboard, saved PNG history, and floating preview as the primary handoff. The default loop is capture -> preview confirms `Copied to Clipboard` -> user switches to Codex -> user presses Cmd+V or drags the saved PNG from the preview/Finder. This avoids synthetic paste events and does not claim that CueShot can control the visible Codex composer.

Existing installs are migrated to this clipboard-first behavior once via `clipboardFirstMigrationVersion`. A previous `autoPasteToCodex=true` preference is treated as stale legacy behavior and reset to `false`; users who still want App Server can explicitly re-enable it from Advanced settings after migration.

## Experimental App Server Model

Optional advanced Codex delivery uses `codex app-server --listen stdio://` over newline-delimited JSON-RPC-like stdio:

1. `initialize` with CueShot client info and capabilities.
2. `initialized` notification.
3. `thread/start` with empty params; the live CLI returns `result.thread.id`.
4. `turn/start` with `threadId` and `input` containing a text item plus a `localImage` item pointing to the saved PNG; the live CLI returns `result.turn.id`.

Live probing on Codex CLI `0.141.0` shows this creates an App Server-backed thread (`source: "vscode"`) and accepts the image-bearing turn. It does not prove that the currently visible Codex desktop composer receives the PNG. For that reason App Server remains advanced/experimental, and the default UI says `Copied to Clipboard` or `Ready to Drag`, not `Sent to visible Codex`, unless a future protocol provides a visible-thread targeting or reveal/open contract.

## Privacy Model

Captures, logs, and history stay local. There is no default upload path, analytics SDK, or remote telemetry.

## Capture Strategy

CueShot normalizes the target rect first, then chooses the best available capture provider for that rect. The preferred path uses ScreenCaptureKit with a display filter and a source rect so CueShot can hide the cursor and exclude its own app windows from third-party captures. Older compatibility paths fall back to region capture or `CGWindowListCreateImage` only when the filtered ScreenCaptureKit plan is unavailable.
