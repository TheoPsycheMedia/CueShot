import AppKit
import SwiftUI

@MainActor
final class CapturePuckController {
    private var panel: NSPanel?
    private let initialPanelSize = CaptureControlMetrics.defaultSize(for: .idle)

    func show(model: AppModel) {
        if panel == nil {
            panel = makePanel(model: model)
            if let panel {
                position(panel)
            }
        }

        if let panel {
            Self.resize(panel, to: CaptureControlMetrics.defaultSize(for: model.captureControlPresentation), animated: false)
        }
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func containsScreenPoint(_ point: CGPoint) -> Bool {
        eventExclusionZones().contains { $0.contains(point) }
    }

    func eventExclusionZones() -> [GestureExclusionZone] {
        guard let panel else { return [] }

        return [
            GestureExclusionZone(
                frame: panel.frame,
                screenFrame: panel.screen?.frame ?? NSScreen.main?.frame
            )
        ]
    }

    private func makePanel(model: AppModel) -> NSPanel {
        let panel = FloatingCapturePanel(
            contentRect: NSRect(origin: .zero, size: initialPanelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .statusBar
        panel.title = "CueShot Capture Control"
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.setAccessibilityElement(true)
        panel.setAccessibilityRole(.window)
        panel.setAccessibilityTitle("CueShot Capture Control")
        panel.contentView = NSHostingView(
            rootView: CapturePuckView(model: model) { [weak panel] size in
                guard let panel else { return }
                Self.resize(panel, to: size, animated: true)
            }
        )
        return panel
    }

    private func position(_ panel: NSPanel) {
        guard let visibleFrame = NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame else {
            return
        }

        panel.setFrameOrigin(CaptureControlPlacement.initialOrigin(for: panel.frame.size, visibleFrame: visibleFrame))
    }

    private static func resize(_ panel: NSPanel, to size: CGSize, animated: Bool) {
        let current = panel.frame
        guard abs(current.width - size.width) > 0.5 || abs(current.height - size.height) > 0.5 else {
            return
        }

        let visibleFrame = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? current
        panel.setFrame(CaptureControlPlacement.resizedFrame(from: current, to: size, visibleFrame: visibleFrame), display: true, animate: animated)
    }
}

enum CaptureControlPlacement {
    static let edgePadding: CGFloat = 12
    static let topPadding: CGFloat = 28
    static let utilityMenuClearance: CGFloat = 220

    static func initialOrigin(for size: CGSize, visibleFrame: CGRect) -> CGPoint {
        let desired = CGPoint(
            x: visibleFrame.maxX - size.width - utilityMenuClearance,
            y: visibleFrame.maxY - size.height - topPadding
        )
        return clampedOrigin(desired, size: size, visibleFrame: visibleFrame, preferredRightClearance: utilityMenuClearance)
    }

    static func resizedFrame(from current: CGRect, to size: CGSize, visibleFrame: CGRect) -> CGRect {
        let desired = CGPoint(
            x: visibleFrame.maxX - size.width - utilityMenuClearance,
            y: current.maxY - size.height
        )
        let origin = clampedOrigin(desired, size: size, visibleFrame: visibleFrame, preferredRightClearance: utilityMenuClearance)
        return CGRect(origin: origin, size: size)
    }

    private static func clampedOrigin(
        _ origin: CGPoint,
        size: CGSize,
        visibleFrame: CGRect,
        preferredRightClearance: CGFloat
    ) -> CGPoint {
        let minX = visibleFrame.minX + edgePadding
        let maxVisibleX = visibleFrame.maxX - size.width - edgePadding
        let maxMenuSafeX = visibleFrame.maxX - size.width - preferredRightClearance
        let maxX = max(minX, min(maxVisibleX, maxMenuSafeX))

        let minY = visibleFrame.minY + edgePadding
        let maxY = max(minY, visibleFrame.maxY - size.height - edgePadding)

        return CGPoint(
            x: min(max(origin.x, minX), maxX),
            y: min(max(origin.y, minY), maxY)
        )
    }
}

private final class FloatingCapturePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct CapturePuckView: View {
    @ObservedObject var model: AppModel
    let resize: (CGSize) -> Void
    @State private var appeared = false

    private var presentation: CaptureControlPresentation {
        model.captureControlPresentation
    }

    var body: some View {
        CueGlassGroup(spacing: 8) {
            content
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .fixedSize(horizontal: true, vertical: true)
                .cueFloatingHUD(cornerRadius: 20)
                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .background(PuckSizeReporter())
                .onPreferenceChange(PuckContentSizePreferenceKey.self) { contentSize in
                    resize(CaptureControlMetrics.size(for: presentation, contentSize: contentSize))
                }
                .onAppear {
                    resize(CaptureControlMetrics.defaultSize(for: presentation))
                }
                .onChange(of: presentation) { _, newPresentation in
                    resize(CaptureControlMetrics.defaultSize(for: newPresentation))
                }
            .scaleEffect(appeared ? 1 : 0.98)
            .opacity(appeared ? 1 : 0)
            .animation(MotionSpec.entrance, value: appeared)
            .onAppear { appeared = true }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch presentation {
        case .idle:
            PuckIdleBar(model: model)
        case .armed:
            PuckArmedBar(model: model)
        case .captured(let capture):
            PuckResultCard(model: model, capture: capture)
        case .permission(let kind):
            PuckPermissionCard(model: model, kind: kind)
        case .failed(let message):
            PuckFailureCard(model: model, message: message)
        }
    }
}

private enum CaptureControlMetrics {
    static func defaultSize(for presentation: CaptureControlPresentation) -> CGSize {
        switch presentation {
        case .idle:
            CGSize(width: 424, height: 96)
        case .armed:
            CGSize(width: 340, height: 62)
        case .captured:
            CGSize(width: 430, height: 142)
        case .permission, .failed:
            CGSize(width: 390, height: 126)
        }
    }

    static func size(for presentation: CaptureControlPresentation, contentSize: CGSize) -> CGSize {
        let fallback = defaultSize(for: presentation)
        guard contentSize.width > 1, contentSize.height > 1 else { return fallback }

        let minSize: CGSize
        let maxSize: CGSize
        switch presentation {
        case .idle:
            minSize = CGSize(width: 398, height: 88)
            maxSize = CGSize(width: 452, height: 108)
        case .armed:
            minSize = CGSize(width: 300, height: 56)
            maxSize = CGSize(width: 370, height: 72)
        case .captured:
            minSize = CGSize(width: 390, height: 118)
            maxSize = CGSize(width: 450, height: 156)
        case .permission, .failed:
            minSize = CGSize(width: 360, height: 112)
            maxSize = CGSize(width: 430, height: 148)
        }

        return CGSize(
            width: min(max(contentSize.width, minSize.width), maxSize.width),
            height: min(max(contentSize.height, minSize.height), maxSize.height)
        )
    }
}

private struct PuckContentSizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

private struct PuckSizeReporter: View {
    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(key: PuckContentSizePreferenceKey.self, value: proxy.size)
        }
    }
}

private struct PuckUtilityMenu: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Menu {
            Button("Copy Last Capture") {
                model.copyLastCapture()
            }
            .disabled(model.selectedCapture == nil)
            Button("Save Capture As…") {
                model.saveSelectedCaptureAs()
            }
            .disabled(model.selectedCapture == nil)
            if let capture = model.selectedCapture {
                Button("Show in Finder") {
                    model.revealCapture(capture)
                }
            }
            Divider()
            Button("Hide Control") {
                model.hideToMenuBar()
            }
            Button("Open CueShot") {
                model.openMainWindow()
            }
            Button("Settings…") {
                model.openSettings()
            }
            Button("Onboarding") {
                model.openOnboarding()
            }
            Divider()
            Button("Quit CueShot") {
                NSApp.terminate(nil)
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .accessibilityIdentifier("CapturePuckMenuButton")
        .accessibilityLabel("Capture control menu")
        .accessibilityHint("Opens capture, file, settings, onboarding, and app controls.")
        .menuStyle(.button)
        .buttonStyle(.plain)
    }
}

private struct PuckStatusGlyph: View {
    @ObservedObject var model: AppModel

    var body: some View {
        CueBrandMark(size: 30, active: model.captureState.isActive)
    }
}

private struct PuckIdleBar: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                CueBrandMark(size: 30, active: false)

                VStack(alignment: .leading, spacing: 1) {
                    Text("CueShot Control")
                        .font(.system(size: 12, weight: .semibold))
                    Text(model.selectedMode.userFacingIdleInstruction)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .layoutPriority(1)

                Spacer(minLength: 4)

                Button {
                    model.armCaptureFromFloatingControl()
                } label: {
                    Label("Capture", systemImage: model.selectedMode.symbol)
                        .labelStyle(.titleAndIcon)
                        .frame(width: 82)
                }
                .accessibilityIdentifier("CapturePuckCaptureButton")
                .buttonStyle(PressableMotionStyle())
                .cueTintedGlass(CueColor.accent.opacity(0.22), cornerRadius: 12, interactive: true)

                PuckHideButton(model: model)
                PuckUtilityMenu(model: model)
            }

            PuckModePicker(model: model)
        }
    }
}

private struct PuckHideButton: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Button {
            model.hideToMenuBar()
        } label: {
            Image(systemName: "eye.slash")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 30, height: 28)
        }
        .accessibilityIdentifier("CapturePuckHideButton")
        .accessibilityLabel("Hide Capture Control")
        .accessibilityHint("Hides CueShot windows and leaves the menu bar item available.")
        .help("Hide Capture Control")
        .buttonStyle(PressableMotionStyle())
        .cueTintedGlass(CueColor.secondaryAccent.opacity(0.12), cornerRadius: 12, interactive: true)
    }
}

private struct PuckArmedBar: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 9) {
            PuckStatusGlyph(model: model)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.selectedMode.userFacingArmedInstruction)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(model.selectedMode.presentation.contextualHint ?? "Press Esc to cancel.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                model.cancelOneClickCapture()
            } label: {
                Label("Cancel", systemImage: "xmark")
                    .labelStyle(.titleAndIcon)
                    .frame(width: 78)
            }
            .accessibilityIdentifier("CapturePuckStopButton")
            .buttonStyle(PressableMotionStyle())
            .cueTintedGlass(.orange.opacity(0.18), cornerRadius: 12, interactive: true)
        }
    }
}

private struct PuckModePicker: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 5) {
            ForEach(CaptureMode.allCases) { mode in
                Button {
                    model.selectModeAndArmCapture(mode)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mode.symbol)
                            .font(.system(size: 10, weight: .semibold))
                        Text(mode.userFacingPickerTitle)
                            .font(.system(size: 9, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .frame(maxWidth: .infinity, minHeight: 26)
                    .foregroundStyle(model.selectedMode == mode ? CueColor.accent : .secondary)
                }
                .accessibilityIdentifier("CapturePuckMode-\(mode.rawValue)")
                .buttonStyle(PressableMotionStyle())
                .cueTintedGlass(
                    (model.selectedMode == mode ? CueColor.accent : CueColor.secondaryAccent).opacity(model.selectedMode == mode ? 0.20 : 0.08),
                    cornerRadius: 9,
                    interactive: true
                )
                .help(mode.userFacingHelpText)
            }
        }
    }
}

private struct PuckPermissionCard: View {
    @ObservedObject var model: AppModel
    let kind: PermissionKind

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                CueBrandMark(size: 28, active: false)
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.presentation.title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(kind.presentation.detail)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                PuckUtilityMenu(model: model)
            }

            HStack(spacing: 8) {
                Button {
                    model.openPermissionSettings(kind)
                } label: {
                    Label(kind.presentation.actionTitle, systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PressableMotionStyle())
                .cueTintedGlass(.orange.opacity(0.18), cornerRadius: 12, interactive: true)

                Button {
                    model.dismissCaptureStatus()
                } label: {
                    Text("Later")
                        .frame(width: 82)
                }
                .buttonStyle(PressableMotionStyle())
                .cueGlass(cornerRadius: 12, interactive: true)
            }
            .font(.system(size: 11, weight: .semibold))
        }
    }
}

private struct PuckFailureCard: View {
    @ObservedObject var model: AppModel
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                CueBrandMark(size: 28, active: false)
                Image(systemName: "xmark.octagon.fill")
                    .foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text(CaptureCopy.failedTitle)
                        .font(.system(size: 13, weight: .semibold))
                    Text(message.isEmpty ? CaptureCopy.failedDetail : message)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                PuckUtilityMenu(model: model)
            }

            HStack(spacing: 8) {
                Button {
                    model.armCaptureFromFloatingControl()
                } label: {
                    Label("Try Again", systemImage: model.selectedMode.symbol)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PressableMotionStyle())
                .cueTintedGlass(CueColor.reticle.opacity(0.18), cornerRadius: 12, interactive: true)

                Button {
                    model.dismissCaptureStatus()
                } label: {
                    Text("Dismiss")
                        .frame(width: 82)
                }
                .buttonStyle(PressableMotionStyle())
                .cueGlass(cornerRadius: 12, interactive: true)
            }
            .font(.system(size: 11, weight: .semibold))
        }
    }
}

private struct PuckResultCard: View {
    @ObservedObject var model: AppModel
    let capture: CaptureRecord

    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                CueBrandMark(size: 28, active: true)
                Label(capture.mode == .ocr && capture.normalizedOCRText != nil ? "Text copied" : CaptureCopy.copiedTitle, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CueColor.success)
                Text("\(capture.mode.userFacingTitle) · \(capture.dimensions) · \(capture.fileSize)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                PuckUtilityMenu(model: model)
            }

            HStack(spacing: 10) {
                thumbnail

                VStack(alignment: .leading, spacing: 7) {
                    Text(capture.mode == .ocr && capture.normalizedOCRText != nil ? CaptureCopy.textFoundDetail : "Paste it anywhere, or drag this thumbnail.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    if let ocrText = capture.normalizedOCRText {
                        Text(ocrText)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.tail)
                    }

                    HStack(spacing: 7) {
                        Button {
                            model.armCaptureFromFloatingControl()
                        } label: {
                            Label("New", systemImage: model.selectedMode.symbol)
                                .frame(maxWidth: .infinity)
                        }
                        Button {
                            model.copyLastCapture()
                        } label: {
                            Label("Copy Again", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        if let _ = capture.normalizedOCRText {
                            Button {
                                model.copyOCRText(capture)
                            } label: {
                                Label("Copy Text", systemImage: "textformat")
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        Button {
                            model.revealCapture(capture)
                        } label: {
                            Label("Finder", systemImage: "folder")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .buttonStyle(PressableMotionStyle())
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Copied to clipboard. \(capture.mode.userFacingTitle) capture, \(capture.dimensions), \(capture.fileSize). Choose New for another capture, paste it, or drag the thumbnail.")
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = model.selectedCaptureImage,
           let url = model.selectedCaptureURL {
            NativeDraggableCaptureThumbnail(image: image, fileURL: url)
                .frame(width: 92, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                }
                .accessibilityLabel("Drag PNG capture")
                .accessibilityHint("Drag this thumbnail into Codex or another app.")
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.08))
                .frame(width: 92, height: 72)
                .overlay {
                    Image(systemName: capture.mode.symbol)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(CueColor.reticle)
                }
                .accessibilityHidden(true)
        }
    }
}

private struct NativeDraggableCaptureThumbnail: NSViewRepresentable {
    let image: NSImage
    let fileURL: URL

    func makeNSView(context: Context) -> CaptureThumbnailDragImageView {
        let view = CaptureThumbnailDragImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        view.wantsLayer = true
        view.layer?.cornerRadius = 12
        view.layer?.masksToBounds = true
        view.toolTip = "Drag PNG capture"
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.image)
        view.setAccessibilityLabel("Drag PNG capture")
        return view
    }

    func updateNSView(_ view: CaptureThumbnailDragImageView, context: Context) {
        view.image = image
        view.fileURL = fileURL
    }
}

private final class CaptureThumbnailDragImageView: NSImageView, NSDraggingSource {
    var fileURL: URL?
    private var mouseDownEvent: NSEvent?
    private var draggingSessionActive = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
    }

    override func mouseDragged(with event: NSEvent) {
        guard !draggingSessionActive,
              let fileURL,
              let pasteboardItem = CaptureDragPayload.makePasteboardItem(fileURL: fileURL),
              let image
        else {
            return
        }

        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        draggingItem.setDraggingFrame(bounds, contents: image)
        draggingSessionActive = true
        let session = beginDraggingSession(
            with: [draggingItem],
            event: mouseDownEvent ?? event,
            source: self
        )
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    override func mouseUp(with event: NSEvent) {
        mouseDownEvent = nil
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        mouseDownEvent = nil
        draggingSessionActive = false
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        true
    }
}
