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
- `CodexAppServerClient`: JSON-RPC client for `codex app-server` local-image turns retained for diagnostics and future protocol work.
- `CodexHandoffService`: clipboard-first handoff reporting, with optional legacy visible-composer Cmd+V delivery that focuses a likely Codex composer through Accessibility or clicks the visible lower composer area before pasting.
- `PermissionService`: macOS Accessibility and Screen Recording status checks.
- `DiagnosticsLogger`: local event log for troubleshooting.

## Accuracy Model

Element and Window modes are exact when the target app exposes useful Accessibility geometry. When Accessibility metadata is unavailable or too coarse, CueShot marks the target as adjusted, window fallback, or estimated rather than pretending the result is exact. Large container roles such as web areas, scroll areas, groups, and windows are treated as lower-confidence element targets when they cover most of the display.

## Clipboard Handoff Model

CueShot treats the clipboard, saved PNG history, and floating preview as the primary handoff. The default loop is capture -> preview confirms `Copied to Clipboard` -> user switches to Codex -> user presses Cmd+V or drags the saved PNG from the preview/Finder. This default avoids synthetic paste events and does not claim that CueShot can control the visible Codex composer.

Existing installs are migrated to clipboard-first behavior once via `clipboardFirstMigrationVersion`. A previous `autoPasteToCodex=true` preference is treated as stale behavior and reset to `false`; users who still want the legacy Cmd+V visible-composer attempt can explicitly re-enable it from Advanced settings after migration.

## Legacy Cmd+V Model

Optional advanced Codex delivery uses the historical visible-composer paste path:

1. Copy the PNG and saved file URL to `NSPasteboard`.
2. Find the real running Codex desktop app.
3. Activate Codex and wait for it to become frontmost.
4. Query Codex's Accessibility tree for a likely composer text area or text field.
5. If a likely candidate exists, set `AXFocused=true` on it.
6. If the composer input is hidden inside a web view and no likely candidate is exposed, derive Codex's front window bounds and click the lower-center composer band.
7. Wait briefly for focus to settle, then post synthetic Cmd+V using `CGEvent`.

If CueShot cannot focus a likely composer or compute a safe visible-composer click, it reports `Codex prompt not focused` and keeps the PNG copied. If it can focus or click the composer area and post the keyboard event, it reports `Paste attempted` rather than `Sent to visible Codex`, because macOS does not provide a reliable receipt that the visible composer attached the image.

## Privacy Model

Captures, logs, and history stay local. There is no default upload path, analytics SDK, or remote telemetry.

## Capture Strategy

CueShot normalizes the target rect first, then chooses the best available capture provider for that rect. The preferred path uses ScreenCaptureKit with a display filter and a source rect so CueShot can hide the cursor and exclude its own app windows from third-party captures. Older compatibility paths fall back to region capture or `CGWindowListCreateImage` only when the filtered ScreenCaptureKit plan is unavailable.
