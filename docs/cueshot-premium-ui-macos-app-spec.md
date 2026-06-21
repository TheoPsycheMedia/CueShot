# CueShot Premium UI + macOS App Spec

Source: ChatGPT Pro Extended thread, retrieved from the visible Chrome session on 2026-06-19.

## 1. Product Positioning And Tagline

CueShot is a tiny, premium macOS capture utility for Codex users who need to point at a UI detail and drop it into an active Codex conversation without switching mental contexts.

Tagline: "Arm, click, and drop any interface detail into Codex."

CueShot should feel less like a screenshot manager and more like a precise optical instrument: compact, calm, native, fast, and trustworthy. The product exists for one narrow workflow: capture the exact visible UI element the user is referencing, prepare a clean PNG, and hand it to Codex with the least possible ceremony. It is not a dashboard, creative suite, annotation tool, cloud sync product, or generic screenshot app.

Primary users are engineers, designers, QA testers, and product builders using Codex to discuss UI bugs, implementation details, visual regressions, websites, desktop apps, or screen states. The hero moment is: click the CueShot menu bar icon, arm the floating capture control, click or drag a visible UI target, then see a polished clipboard preview with Copy, Reveal, and Open actions. The user can paste or drag the PNG into Codex.

The product promise is precision plus calm: "I know what you clicked, I captured only that, and I placed it where you needed it."

## 2. Premium UI Design System

### Visual Direction

CueShot's design language is Capture Lens: graphite and pearl surfaces, machined double-bezel panels, quiet depth, exact spacing, and one precise green optical accent. Avoid bright SaaS gradients, marketing cards, emoji UI, heavy dashboards, or generic blue macOS utility styling.

### Layout Grid

Use an 8 pt base grid with 4 pt optical corrections.

Default main window: 760 x 480 pt. Minimum size: 680 x 420 pt. Maximum size: 920 x 600 pt. Window corner radius: 18 pt. Content padding: 20 pt. Column gap: 16 pt.

Main window layout:

| Region | Width | Purpose |
| --- | ---: | --- |
| Left rail | 72 pt | Capture modes |
| Center lens | Flexible, target 392 pt | Preview, reticle, state |
| Right inspector | 220 pt | Destination, permissions, recents |

The main content area is inset inside a machined panel at 720 x 440 pt when the window is default size. Panel corner radius: 16 pt. Inner panel stroke: 1 pt pearl/graphite contrast. Outer stroke: 1 pt darker bevel.

### Color Tokens

Use semantic color tokens, not raw colors inside views.

| Token | Light | Dark | Use |
| --- | --- | --- | --- |
| `surface.base` | `#F4F1EA` | `#151617` | Window background |
| `surface.panel` | `#ECE8DF` | `#1D1F20` | Main panel |
| `surface.raised` | `#FAF8F3` | `#252728` | Cards, controls |
| `surface.sunken` | `#E2DED4` | `#101112` | Lens well |
| `stroke.primary` | `#C8C1B4` | `#363A3C` | Panel borders |
| `stroke.subtle` | `#DDD7CB` | `#2A2D2F` | Dividers |
| `text.primary` | `#17191A` | `#F4F1EA` | Primary text |
| `text.secondary` | `#62605A` | `#A8AAA8` | Secondary text |
| `text.tertiary` | `#928E84` | `#727674` | Captions |
| `accent.reticle` | `#38D98B` | `#38D98B` | Reticle, ready state |
| `accent.warning` | `#E0A13A` | `#F0B44D` | Permission partial |
| `accent.error` | `#D95C5C` | `#EF6A6A` | Error states |
| `accent.codex` | `#F5F1E8` | `#EDE7DA` | Codex destination chip |

The reticle green must be used sparingly. No more than one large green element should be visible on a surface at a time.

### Type Scale

Use SF Pro through SwiftUI system fonts.

| Style | Size | Weight | Line Height | Use |
| --- | ---: | --- | ---: | --- |
| `display.mini` | 20 pt | Semibold | 25 pt | Main state title |
| `title` | 15 pt | Semibold | 20 pt | Section headers |
| `body` | 13 pt | Regular | 18 pt | Primary UI copy |
| `body.medium` | 13 pt | Medium | 18 pt | Buttons, labels |
| `caption` | 11 pt | Regular | 14 pt | Metadata |
| `micro` | 10 pt | Medium | 12 pt | Status pills, shortcuts |

Use tabular figures for capture dimensions, timestamps, and file sizes.

### Reticle And Lens Treatment

The lens is the visual center of CueShot.

Default lens well: 392 x 312 pt, minimum 340 x 260 pt, corner radius 22 pt. Background: `surface.sunken`. Add an inner shadow: y 1 pt, blur 6 pt, black 18% in dark mode or black 8% in light mode. Add a double bezel: outer 1 pt `stroke.primary`, inner 1 pt `stroke.subtle`.

Reticle:

- Center crosshair: 44 x 44 pt.
- Stroke: 1.5 pt `accent.reticle`.
- Center dot: 5 x 5 pt circle.
- Four corner brackets: 18 x 18 pt, stroke 1.5 pt.
- Reticle opacity: 90% when Ready, 100% when Armed, 45% when inactive.
- Armed pulse: scale 1.0 to 1.035 to 1.0 over 900 ms, opacity 85% to 100% to 85%.

Capture preview should appear inside the lens with a 12 pt inset, 14 pt corner radius, and subtle highlight stroke. If no capture exists, show a pearl/graphite empty plate with reticle and the text: "Choose a mode, arm the floating control, then click or drag."

### Icon Style

Icons are monoline, rounded, and technical. Stroke width: 1.75 pt. Size: 20 x 20 pt in rail, 16 x 16 pt in inspector. Use no filled multicolor symbols except state dots. Preferred SF Symbols: `scope`, `macwindow`, `selection.pin.in.out`, `display`, `checkmark.circle.fill`, `exclamationmark.triangle.fill`, `doc.on.clipboard`, `arrowshape.turn.up.right`.

Custom app icon: graphite rounded square with inset pearl lens ring and a single green reticle dot. Avoid camera metaphors.

### Motion

Motion must be short, spatial, and useful.

| Motion | Duration | Curve |
| --- | ---: | --- |
| Popover open | 140 ms | easeOut |
| State pill change | 120 ms | easeInOut |
| Reticle armed pulse | 900 ms loop | easeInOut |
| Capture flash | 90 ms in, 160 ms out | easeOut |
| Preview settle | 180 ms | spring response 0.28, damping 0.82 |
| Error shake | 220 ms | horizontal +/- 5 pt |

No bouncy marketing animation. No full-screen confetti. Paste-attempt state uses one restrained check pulse only; do not imply verified delivery unless receipt is actually verified.

### Components

Status Pill: Height 24 pt, horizontal padding 10 pt, radius 12 pt. Dot size 7 pt. Text micro. States: Ready, Armed, Capturing, Paste Attempted, Needs Permission, Copy Fallback.

Primary Button: Height 32 pt, radius 9 pt, horizontal padding 14 pt. Text `body.medium`. Default fill `text.primary`, text inverse. Disabled opacity 45%.

Secondary Button: Height 30 pt, radius 8 pt, fill `surface.raised`, 1 pt stroke `stroke.primary`.

Inspector Card: Width 188 pt, padding 12 pt, radius 12 pt, fill `surface.raised`, stroke `stroke.subtle`.

Recent Capture Row: Height 48 pt. Thumbnail 40 x 28 pt, radius 6 pt. Title 13 pt medium. Metadata 11 pt. Hover reveals Copy and Reveal buttons.

## 3. Surfaces

### Menu Bar Item

Use `NSStatusItem` with a compact pill, not a permanent icon-only mystery item.

Width: dynamic, 72-104 pt. Height: macOS menu bar standard. Content: tiny reticle glyph plus status label.

Labels:

- Ready
- Armed
- Capturing
- Paste Attempted
- Needs AX
- Needs Screen
- Fallback

Ready pill uses graphite text and green dot. Armed pill adds a thin green ring. Capturing shows spinner. Clicking opens the menubar popover.

### Menubar Popover

Size: 360 x 420 pt. Corner radius follows system popover. Content padding: 16 pt.

Popover structure:

- Header: CueShot wordmark, status pill.
- Mini lens preview: 328 x 180 pt.
- Destination card: Codex, active app status, paste readiness.
- Permission card: Screen Recording and Accessibility rows.
- Recent captures: latest 3.
- Footer: Open CueShot, Copy Last PNG, Preferences.

The popover is the default home for the app. It must be useful without opening the main window.

### Main Window

Use a compact SwiftUI window backed by AppKit for precise sizing and titlebar behavior. Hide toolbar. Use full-size content view. Titlebar traffic lights remain visible. Default open position: centered horizontally, 30% from top.

Main window contains the full Capture Lens layout: left rail, center lens, right inspector. It is for setup, inspection, and recent capture management, not continuous work.

### Capture Overlay

When Armed or Capturing, create a transparent, borderless `NSPanel` per active display at screen level above normal windows but below system permission dialogs. The overlay must ignore mouse events except during Area mode drag. It renders:

- Current hit-test rectangle.
- Reticle centered on cursor.
- Dimension label, for example `286 x 144`.
- App/role label, for example `Safari - AXButton`.
- Optional confidence badge: Exact, Window, Area fallback.

Overlay rectangle style: 1.5 pt green stroke, 6 pt corner radius, outside dim at black 10% only while Capturing. Do not darken the whole screen during normal Ready state.

### Permission/Error Sheets

Use compact sheets attached to main window and cards in popover. Avoid alarming system-modal language.

Sheet size: 440 x 280 pt. Header icon 28 pt. Title 20 pt semibold. Body 13 pt. Primary action opens the relevant System Settings pane where possible. Secondary action: "Use Copy PNG Only" or "Not Now."

### Recent Captures

Store and show up to 30 captures. In UI, show latest 8 in main window and latest 3 in popover. Each capture has thumbnail, app/source, mode, dimensions, timestamp, destination result, and actions: Copy PNG, Reveal in Finder, Delete.

## 4. Interaction Model

### Core Activation: Menu Bar + Floating Control

The primary capture path is deliberate and visible: the menu bar icon shows the floating control, the user presses Arm, and CueShot captures the next click or drag according to the selected mode.

The floating control remains the canonical activation surface because it is discoverable, cancellable, and avoids surprising global gesture conflicts. Command + triple-click may remain as an optional advanced shortcut, but it must never be the only way to start capture.

### State Machine

States:

- Ready: permissions valid, Codex may or may not be focused.
- Armed: floating control pressed; overlay reticle follows cursor.
- Capturing: click or drag recognized; freeze target rect and capture frame.
- Paste Attempted: PNG copied and paste shortcut sent toward Codex, but attachment receipt is not verified.
- Permission Needed: missing Screen Recording or Accessibility.
- Codex Not Focused: capture succeeds but auto-paste is unsafe.
- Copied: PNG copied to clipboard; user can paste manually, drag the preview, or reveal the saved PNG.

State transitions:

- Ready -> Armed: floating Arm button pressed.
- Armed -> Ready: Escape, Cancel, or completed capture.
- Armed -> Capturing: valid click or drag for selected mode.
- Capturing -> Paste Attempted: Codex focused and paste shortcut posted.
- Capturing -> Copy Fallback: Codex not focused, paste blocked, or target app unknown.
- Any state -> Permission Needed: permission check fails.

### Capture Modes

Left rail modes:

- Element: default. Uses Accessibility hit-testing to find clicked UI element bounds.
- Selection: estimated crop around the clicked point when the user wants a fast visual region without relying on exact AX bounds.
- Window: captures containing window.
- Area: user drags a rectangle after arming.
- Screen: captures current display.

Element mode should attempt AX first, then window fallback, then estimated Selection-style crop around the clicked visual region if bounds are unavailable. Selection and Area must remain separate: Selection is click-estimated; Area is drag-defined.

### Codex Destination Behavior

Destination is fixed to Codex in MVP. If the active app/window appears to be Codex, CueShot attempts automatic paste. If not, it still captures and copies PNG, then shows "Copied PNG - focus Codex and paste."

The app must never call the OpenAI API.

## 5. macOS Implementation Architecture

CueShot is a native macOS app using SwiftUI for product UI and AppKit interop for system integration. AppKit remains necessary for `NSStatusItem`, `NSPopover`, borderless overlay panels, global event coordination, pasteboard handling, and activation/paste operations.

Minimum target: macOS 14.0. Recommended target for v1: macOS 14+, with conditional paths for newer ScreenCaptureKit APIs when available.

Architecture style: single-process menu bar app with observable app state.

Top-level modules:

- `CueShotApp`
- `DesignSystem`
- `StatusBar`
- `CaptureOverlay`
- `CaptureCore`
- `CodexHandoff`
- `Permissions`
- `Storage`
- `Diagnostics`

Use Swift concurrency for capture pipeline operations. UI state should live in a `@MainActor AppModel`.

### Screen Capture

Use ScreenCaptureKit as the primary capture path. For still images, prefer `SCScreenshotManager` when available. If unavailable or insufficient for a crop, capture the containing display/window frame and crop in Core Graphics. `CGWindowListCreateImage` is deprecated and should be treated only as a compatibility fallback if absolutely necessary.

### Accessibility Hit Testing

Use `AXUIElementCreateSystemWide()` and `AXUIElementCopyElementAtPosition` for element hit testing.

Read these attributes when available:

- `kAXRoleAttribute`
- `kAXSubroleAttribute`
- `kAXTitleAttribute`
- `kAXDescriptionAttribute`
- `kAXPositionAttribute`
- `kAXSizeAttribute`
- `kAXWindowAttribute`

Bounds must be converted carefully between AX screen coordinates, Core Graphics display coordinates, backing scale, and image pixel coordinates.

### Clipboard And Paste

Use `NSPasteboard.general` to write PNG data with pasteboard type `.png`.

Auto-paste sequence:

1. Encode capture as PNG.
2. Save to history.
3. Write PNG and file URL to clipboard.
4. Resolve Codex target app/window.
5. Activate target app with `NSRunningApplication.activate`.
6. Send Command-V via `CGEvent` keyboard event.
7. Verify clipboard write; keep the floating preview visible and show Copied to Clipboard. Do not show Sent unless an optional advanced App Server receipt is actually verified.

## 6. Core Services And Classes

### AppModel

`@MainActor ObservableObject`

Owns global UI state.

Properties:

- `captureState: CaptureState`
- `selectedMode: CaptureMode`
- `destination: Destination = .codex`
- `permissions: PermissionStatus`
- `recentCaptures: [CaptureRecord]`
- `lastError: CueShotError?`

### StatusBarController

AppKit controller for menu bar item and popover.

Responsibilities:

- Create `NSStatusItem`.
- Render status pill.
- Open/close `NSPopover`.
- Reflect state changes within 100 ms.

### GlobalGestureMonitor

Responsibilities:

- Install/remove event tap.
- Track armed click and drag events after the floating control is pressed.
- Support optional advanced shortcut thresholds without making them primary.
- Publish armed, cancelled, click, drag, and move snapshots for the capture flow.
- Re-enable tap if macOS disables it.

### AXHitTestService

Responsibilities:

- Check Accessibility trust.
- Hit-test point.
- Extract AX metadata and bounds.
- Determine confidence: `.exact`, `.estimated`, `.unavailable`.
- Provide window fallback candidate.

### ShareableContentService

Responsibilities:

- Fetch ScreenCaptureKit displays/windows.
- Map AX/window bounds to `SCDisplay` or `SCWindow`.
- Cache shareable content for 2 seconds to avoid slow repeated fetches.

### CaptureService

Responsibilities:

- Execute mode-specific capture.
- Convert coordinates.
- Crop image.
- Encode PNG.
- Generate thumbnail.
- Return `CaptureResult`.

### OverlayWindowController

Responsibilities:

- Create one overlay panel per display.
- Draw reticle, target rect, labels.
- Update at pointer cadence while Armed.
- Freeze and flash during Capturing.
- Dismiss after Paste Attempted/Fallback.

### CodexHandoffService

Responsibilities:

- Identify likely Codex app/window.
- Write PNG to pasteboard.
- Activate Codex when safe.
- Send paste event.
- Return `HandoffResult`.

Codex detection should support configurable bundle IDs/window title substrings. MVP defaults: title contains `Codex`, `ChatGPT`, or known local Codex shell names if present. Do not hard-code fragile assumptions as the only path.

### CaptureHistoryStore

Responsibilities:

- Persist metadata as JSON.
- Store PNG and thumbnail files.
- Enforce 30-item limit and max disk usage.
- Delete orphaned files.

### PermissionService

Responsibilities:

- Check Screen Recording and Accessibility.
- Trigger AX prompt using `AXIsProcessTrustedWithOptions`.
- Open System Settings panes.
- Publish permission changes when app becomes active.

## 7. Data Model And Storage

### Enums

```swift
enum CaptureMode: String, Codable {
    case element, selection, window, area, screen
}

enum CaptureState: Equatable {
    case ready
    case armed(point: CGPoint?)
    case capturing
    case pasteAttempted
    case permissionNeeded(PermissionKind)
    case codexNotFocused
    case copyFallback(reason: String)
}

enum TargetConfidence: String, Codable {
    case exact, estimated, windowFallback, manualArea
}
```

### Capture Record

```swift
struct CaptureRecord: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    let mode: CaptureMode
    let confidence: TargetConfidence
    let sourceAppName: String?
    let sourceBundleID: String?
    let axRole: String?
    let axTitle: String?
    let screenFramePoints: CGRect
    let pixelSize: CGSize
    let pngRelativePath: String
    let thumbnailRelativePath: String
    let fileSizeBytes: Int
    let handoffStatus: HandoffStatus
}
```

### Storage Location

Use Application Support:

```text
~/Library/Application Support/CueShot/
```

Structure:

```text
CueShot/
  History/
    captures.json
    PNG/
      <uuid>.png
    Thumbnails/
      <uuid>.jpg
  Logs/
    cueshot.log
  Preferences.json
```

History limit: 30 captures. Disk limit: 150 MB. On launch and after each capture, remove records beyond limit and delete orphan files.

Preferences:

```swift
struct CueShotPreferences: Codable {
    var launchAtLogin: Bool
    var defaultMode: CaptureMode
    var autoPasteToCodex: Bool
    var keepHistoryCount: Int
    var codexWindowTitleHints: [String]
    var showCaptureFlash: Bool
}
```

Defaults: launch at login false, mode element, auto-paste true, keep history 30, show flash true.

## 8. Privacy, Security, And Permissions

CueShot requires two sensitive permissions:

- Screen Recording: required to capture visible screen pixels.
- Accessibility: required for global gesture confidence, AX hit-testing, app/window metadata, and precise element bounds.

Privacy rules:

- No cloud sync.
- No analytics in MVP.
- No OpenAI API calls.
- No network entitlement unless a future local integration explicitly requires it.
- Captures stay on device.
- Clipboard is modified only after a successful capture or explicit Copy PNG action.
- Logs must never include raw image data or OCR text.
- Recent capture history is user-clearable.

Permission copy must be plain and specific:

Screen Recording: "CueShot needs Screen Recording to capture the UI element you clicked. Captures stay on this Mac."

Accessibility: "CueShot needs Accessibility to detect the element under your cursor and paste the PNG into Codex."

If Accessibility is missing, Element mode is disabled and Window/Area/Screen remain available if Screen Recording is granted. If Screen Recording is missing, no capture modes are available.

## 9. MVP Scope, V2 Scope, Milestones, Verification Tests, Risks

### MVP Scope

MVP must ship:

- Menu bar status pill.
- Menubar popover.
- Main Capture Lens window.
- Menu bar activation that shows the floating control.
- Floating Arm control for click and drag capture.
- Element mode with AX hit-test and bounds crop.
- Selection mode with estimated click crop.
- Window, Area, and Screen modes.
- Screen Recording and Accessibility permission UI.
- Capture overlay with reticle and target rectangle.
- PNG encoding.
- Clipboard Copy PNG fallback.
- Auto-paste into active/focused Codex-like window when safe.
- Recent capture history with 30-item limit.
- Local-only storage.
- Light and dark appearance.

MVP explicitly excludes:

- Annotation tools.
- Cloud sync.
- OpenAI API integration.
- OCR.
- Team accounts.
- Browser extension.
- Automatic semantic UI understanding beyond AX metadata.

### V2 Scope

V2 may add:

- Official local Codex ingest hook if Codex exposes one.
- Per-app capture profiles.
- Better browser DOM element bridge via optional extension.
- Capture delay.
- Multi-capture batch mode.
- Quick Look preview.
- Drag capture directly from popover.
- Custom keyboard shortcuts for showing, hiding, or arming the floating control.
- Redaction tools for sensitive regions.
- Export naming templates.
- Optional local-only image compression settings.

### Implementation Milestones

Milestone 1: Shell and Design System

Build SwiftUI app shell, status bar item, popover, main window, design tokens, static Capture Lens UI, and mock states.

Acceptance: app launches as menu bar utility, status pill updates from mock state, main window matches 760 x 480 spec.

Milestone 2: Permissions

Implement `PermissionService`, permission cards, sheets, System Settings open actions, and state gating.

Acceptance: missing AX or Screen Recording displays correct UI and disables unavailable capture modes.

Milestone 3: Floating Control and Overlay

Implement the menu bar activation path, floating capture control, `GlobalGestureMonitor`, and `OverlayWindowController`.

Acceptance: clicking the menu bar icon shows the floating control; pressing Arm enters Armed state; click or drag triggers Capturing; overlay draws reticle on all displays.

Milestone 4: AX Targeting

Implement AX hit-test, bounds extraction, metadata, coordinate conversion, and confidence reporting.

Acceptance: clicking common Safari, Finder, Xcode, and System Settings elements returns plausible bounds and labels.

Milestone 5: Capture Pipeline

Implement ScreenCaptureKit display/window capture, crop, PNG encode, thumbnail, history persistence.

Acceptance: captured PNG dimensions match target bounds within +/- 2 px at 1x and +/- 4 px at 2x Retina scale.

Milestone 6: Codex Handoff

Implement pasteboard write, Codex target detection, app activation, paste event, and fallback.

Acceptance: when Codex is focused, capture appears in conversation input; when not focused, PNG is copied and UI says Copy Fallback.

Milestone 7: Polish and Reliability

Add transitions, error handling, recents actions, storage cleanup, logs, keyboard accessibility, and appearance QA.

Acceptance: no visible debug UI, no uncaught capture failures, all required states have polished UI.

### Verification Tests

Unit tests:

- Triple-click timing and distance thresholds.
- State machine transitions.
- Permission gating.
- Coordinate conversion across scale factors.
- History pruning.
- Preferences encode/decode.

Integration tests:

- AX hit-testing with mock AX wrappers.
- Pasteboard PNG write/read.
- Capture crop correctness using known test windows.
- Overlay creation across multiple displays.

Manual QA matrix:

| Scenario | Expected Result |
| --- | --- |
| Command held | Armed state appears |
| Command released | Ready state returns |
| Triple-click AX button | Exact element captured |
| AX unavailable | Permission Needed |
| Screen Recording unavailable | Capture disabled |
| Codex focused | PNG pasted |
| Codex not focused | PNG copied fallback |
| External display Retina/non-Retina | Crop remains accurate |
| Full-screen app | Overlay appears where allowed |
| Secure/password field | Avoid AX title capture; capture only if screen permission allows |
| Large PNG > 10 MB | Save succeeds, UI shows size |
| App relaunch | Recent captures reload |

### Known Risks And Tradeoffs

Precise element capture is not guaranteed across all apps. AX quality varies. Some apps expose accurate element bounds; others expose only windows, groups, or no useful element. CueShot must communicate confidence and fall back gracefully.

Global shortcuts may conflict with app behavior. The visible floating control is the safer default because the user explicitly arms capture, can cancel it, and can see what mode is active before clicking. Any advanced global shortcut should remain optional.

ScreenCaptureKit favors windows/displays, not arbitrary AX elements. The reliable strategy is to capture the containing display or window and crop to AX bounds. This makes coordinate accuracy critical.

Auto-paste into Codex is inherently heuristic. Without an official local ingest hook, v1 depends on pasteboard plus app activation. It should never pretend this is a formal API integration.

Multi-display coordinates are easy to mishandle. macOS coordinate spaces differ between AX, Core Graphics, SwiftUI, and backing pixels. Build conversion tests early.

Privacy perception matters. A global listener plus screen capture utility can feel invasive. The UI must always show status clearly, request permissions only when needed, and keep all data local.

Premium UI can slow MVP if overbuilt. The product should implement the exact visual system above, but avoid custom rendering where native SwiftUI/AppKit controls meet the spec. The premium feel comes from restraint, spacing, materials, and reliable state feedback, not decorative complexity.
