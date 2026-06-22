import AppKit
import SwiftUI

@MainActor
final class CapturePuckController {
    private var panel: NSPanel?
    private let initialPanelSize = CaptureControlPresentation.idle.panelSize

    func show(model: AppModel) {
        if panel == nil {
            panel = makePanel(model: model)
            if let panel {
                position(panel)
            }
        }

        if let panel {
            Self.resize(panel, to: model.captureControlPresentation.panelSize, animated: false)
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
        panel.appearance = NSAppearance(named: .darkAqua)
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
            .preferredColorScheme(.dark)
        )
        return panel
    }

    private func position(_ panel: NSPanel) {
        guard let visibleFrame = NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame else {
            return
        }

        let margin: CGFloat = 28
        let size = panel.frame.size
        let origin = CGPoint(
            x: visibleFrame.maxX - size.width - margin,
            y: visibleFrame.maxY - size.height - margin
        )
        panel.setFrameOrigin(origin)
    }

    private static func resize(_ panel: NSPanel, to size: CGSize, animated: Bool) {
        let current = panel.frame
        guard abs(current.width - size.width) > 0.5 || abs(current.height - size.height) > 0.5 else {
            return
        }

        var origin = CGPoint(x: current.maxX - size.width, y: current.maxY - size.height)
        let visibleFrame = panel.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? current
        origin.x = min(max(origin.x, visibleFrame.minX + 8), visibleFrame.maxX - size.width - 8)
        origin.y = min(max(origin.y, visibleFrame.minY + 8), visibleFrame.maxY - size.height - 8)

        panel.setFrame(NSRect(origin: origin, size: size), display: true, animate: animated)
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
                .frame(width: presentation.panelSize.width, height: presentation.panelSize.height)
                .cueGlass(cornerRadius: 20, interactive: true)
                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .onAppear {
                    resize(presentation.panelSize)
                }
                .onChange(of: presentation) { _, newPresentation in
                    resize(newPresentation.panelSize)
                }
            .scaleEffect(appeared ? 1 : 0.96)
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

private extension CaptureControlPresentation {
    var panelSize: CGSize {
        switch self {
        case .idle:
            CGSize(width: 420, height: 92)
        case .armed:
            CGSize(width: 318, height: 62)
        case .captured:
            CGSize(width: 420, height: 152)
        case .permission, .failed:
            CGSize(width: 390, height: 132)
        }
    }
}

private struct PuckUtilityMenu: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Menu {
            Button("Copy Last PNG") {
                model.copyLastCapture()
            }
            .disabled(model.selectedCapture == nil)
            Button("Save PNG As...") {
                model.saveSelectedCaptureAs()
            }
            .disabled(model.selectedCapture == nil)
            if let capture = model.selectedCapture {
                Button("Reveal PNG") {
                    model.revealCapture(capture)
                }
            }
            Divider()
            Button("Hide Button") {
                model.hideCapturePuck()
            }
            Button("Open CueShot") {
                model.openMainWindow()
            }
            Button("Settings...") {
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
        ZStack {
            Circle()
                .fill((model.captureState.isActive ? CueColor.reticle : .white).opacity(0.12))
                .frame(width: 30, height: 30)
            Image(systemName: model.captureState.isActive ? "scope" : "viewfinder")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(model.captureState.isActive ? CueColor.reticle : .primary)
        }
        .cueTintedGlass((model.captureState.isActive ? CueColor.reticle : .white).opacity(0.12), cornerRadius: 15)
    }
}

private struct PuckIdleBar: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 8) {
                PuckStatusGlyph(model: model)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Capture for Codex")
                        .font(.system(size: 12, weight: .semibold))
                    Text(model.selectedMode.puckIdleDetail)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Button {
                    model.armCaptureFromFloatingControl()
                } label: {
                    Label("Arm", systemImage: "scope")
                        .labelStyle(.titleAndIcon)
                        .frame(width: 68)
                }
                .accessibilityIdentifier("CapturePuckCaptureButton")
                .buttonStyle(PressableMotionStyle())
                .cueTintedGlass(CueColor.reticle.opacity(0.22), cornerRadius: 12, interactive: true)
                PuckUtilityMenu(model: model)
            }

            PuckModePicker(model: model)
        }
    }
}

private struct PuckArmedBar: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 9) {
            PuckStatusGlyph(model: model)
            VStack(alignment: .leading, spacing: 2) {
                Text(model.selectedMode.puckArmedTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Text(model.selectedMode.puckArmedDetail)
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
                        Text(mode.puckPickerTitle)
                            .font(.system(size: 9, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .frame(maxWidth: .infinity, minHeight: 26)
                    .foregroundStyle(model.selectedMode == mode ? CueColor.reticle : .secondary)
                }
                .accessibilityIdentifier("CapturePuckMode-\(mode.rawValue)")
                .buttonStyle(PressableMotionStyle())
                .cueTintedGlass(
                    (model.selectedMode == mode ? CueColor.reticle : .white).opacity(model.selectedMode == mode ? 0.18 : 0.07),
                    cornerRadius: 9,
                    interactive: true
                )
                .help(mode.helpText)
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
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(kind.title) needed")
                        .font(.system(size: 13, weight: .semibold))
                    Text(kind.message)
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
                    Label("Open Settings", systemImage: "gearshape")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PressableMotionStyle())
                .cueTintedGlass(.orange.opacity(0.18), cornerRadius: 12, interactive: true)

                Button {
                    model.dismissCaptureStatus()
                } label: {
                    Text("Not Now")
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
                Image(systemName: "xmark.octagon.fill")
                    .foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Capture failed")
                        .font(.system(size: 13, weight: .semibold))
                    Text(message)
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
                Label("Copied", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CueColor.reticle)
                Text("\(capture.mode.title) · \(capture.dimensions) · \(capture.fileSize)")
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
                    Text("Press Cmd+V in Codex or drag this thumbnail.")
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
                            Label("Copy", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        if let _ = capture.normalizedOCRText {
                            Button {
                                model.copyOCRText(capture)
                            } label: {
                                Label("OCR", systemImage: "textformat")
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        Button {
                            model.revealCapture(capture)
                        } label: {
                            Label("Reveal", systemImage: "folder")
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
        .accessibilityLabel("Copied. \(capture.mode.title) capture, \(capture.dimensions), \(capture.fileSize). Choose New for another capture, press Command V in Codex, or drag the thumbnail.")
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
