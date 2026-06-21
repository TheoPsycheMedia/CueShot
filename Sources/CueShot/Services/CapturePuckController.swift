import AppKit
import SwiftUI

@MainActor
final class CapturePuckController {
    private var panel: NSPanel?
    private let panelSize = NSSize(width: 468, height: 288)

    func show(model: AppModel) {
        if panel == nil {
            panel = makePanel(model: model)
        }

        if let panel, !panel.isVisible {
            position(panel)
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
            contentRect: NSRect(origin: .zero, size: panelSize),
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
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.setAccessibilityElement(true)
        panel.setAccessibilityRole(.window)
        panel.setAccessibilityTitle("CueShot Capture Control")
        panel.contentView = NSHostingView(rootView: CapturePuckView(model: model).preferredColorScheme(.dark))
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
}

private final class FloatingCapturePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct CapturePuckView: View {
    @ObservedObject var model: AppModel
    @State private var appeared = false

    var body: some View {
        CueGlassGroup(spacing: 8) {
            VStack(spacing: 10) {
                HStack(spacing: 11) {
                    statusGlyph

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                        Text(detail)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    captureActionButton
                    utilityMenu
                }

                modePicker
                clipboardPreview
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: 468, height: 288)
            .cueGlass(cornerRadius: 24, interactive: true)
            .scaleEffect(appeared ? 1 : 0.96)
            .opacity(appeared ? 1 : 0)
            .animation(MotionSpec.entrance, value: appeared)
            .onAppear { appeared = true }
        }
    }

    @ViewBuilder
    private var clipboardPreview: some View {
        if let capture = model.selectedCapture {
            CapturePuckPreviewCard(model: model, capture: capture)
        } else {
            CapturePuckPreviewPlaceholder()
        }
    }

    @ViewBuilder
    private var captureActionButton: some View {
        if model.oneClickCaptureArmed {
            Button {
                model.cancelOneClickCapture()
            } label: {
                Label("Cancel", systemImage: "xmark")
                    .labelStyle(.titleAndIcon)
                    .frame(width: 86)
            }
            .accessibilityIdentifier("CapturePuckStopButton")
            .buttonStyle(PressableMotionStyle())
            .cueTintedGlass(.orange.opacity(0.18), cornerRadius: 14, interactive: true)
        } else {
            Button {
                model.armCaptureFromFloatingControl()
            } label: {
                Label("Arm", systemImage: "scope")
                    .labelStyle(.titleAndIcon)
                    .frame(width: 76)
            }
            .accessibilityIdentifier("CapturePuckCaptureButton")
            .buttonStyle(PressableMotionStyle())
            .cueTintedGlass(CueColor.reticle.opacity(0.22), cornerRadius: 14, interactive: true)
        }
    }

    private var utilityMenu: some View {
        Menu {
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
        .accessibilityHint("Opens CueShot settings, onboarding, and app controls.")
        .menuStyle(.button)
        .buttonStyle(.plain)
    }

    private var modePicker: some View {
        HStack(spacing: 6) {
            ForEach(CaptureMode.allCases) { mode in
                Button {
                    model.selectMode(mode)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: mode.symbol)
                            .font(.system(size: 13, weight: .semibold))
                        Text(mode.puckPickerTitle)
                            .font(.system(size: 9, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(model.selectedMode == mode ? CueColor.reticle : .secondary)
                }
                .accessibilityIdentifier("CapturePuckMode-\(mode.rawValue)")
                .buttonStyle(PressableMotionStyle())
                .cueTintedGlass((model.selectedMode == mode ? CueColor.reticle : .white).opacity(model.selectedMode == mode ? 0.20 : 0.08), cornerRadius: 13, interactive: true)
                .help(mode.helpText)
            }
        }
    }

    private var statusGlyph: some View {
        ZStack {
            Circle()
                .fill((model.oneClickCaptureArmed ? CueColor.reticle : .white).opacity(0.12))
                .frame(width: 42, height: 42)
            Image(systemName: model.oneClickCaptureArmed ? "scope" : "viewfinder")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(model.oneClickCaptureArmed ? CueColor.reticle : .primary)
        }
        .cueTintedGlass((model.oneClickCaptureArmed ? CueColor.reticle : .white).opacity(0.12), cornerRadius: 21)
    }

    private var title: String {
        model.oneClickCaptureArmed ? model.selectedMode.puckArmedTitle : model.selectedMode.puckIdleTitle
    }

    private var detail: String {
        model.oneClickCaptureArmed ? model.selectedMode.puckArmedDetail : model.selectedMode.puckIdleDetail
    }
}

private struct CapturePuckPreviewCard: View {
    @ObservedObject var model: AppModel
    let capture: CaptureRecord

    var body: some View {
        HStack(spacing: 10) {
            thumbnail

            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("Copied to Clipboard", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CueColor.reticle)
                    Text("\(capture.mode.title) · \(capture.dimensions) · \(capture.fileSize)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                HStack(spacing: 7) {
                    Button {
                        model.copyLastCapture()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }

                    Button {
                        model.revealCapture(capture)
                    } label: {
                        Label("Reveal", systemImage: "folder")
                            .frame(maxWidth: .infinity)
                    }

                    Button {
                        model.openMainWindow()
                    } label: {
                        Label("Open", systemImage: "arrow.up.forward.app")
                            .frame(maxWidth: .infinity)
                    }
                }
                .font(.system(size: 10, weight: .semibold))
                .labelStyle(.titleAndIcon)
                .buttonStyle(PressableMotionStyle())
            }
        }
        .padding(9)
        .frame(height: 102)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(CueColor.reticle.opacity(0.18), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .onDrag {
            guard let url = model.selectedCaptureURL,
                  let provider = NSItemProvider(contentsOf: url)
            else {
                return NSItemProvider(object: capture.sourceAppName as NSString)
            }
            return provider
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Clipboard preview. \(capture.mode.title) capture, \(capture.dimensions), \(capture.fileSize). Copied to clipboard.")
        .accessibilityHint("Copy again, reveal the saved PNG in Finder, open CueShot, or drag this preview into another app.")
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = model.selectedCaptureImage {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 92, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                }
                .accessibilityHidden(true)
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

private struct CapturePuckPreviewPlaceholder: View {
    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.08))
                .frame(width: 92, height: 64)
                .overlay {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text("Clipboard preview")
                    .font(.system(size: 12, weight: .semibold))
                Text("Your next capture will appear here.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(9)
        .frame(height: 88)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(.white.opacity(0.09), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Clipboard preview. Your next capture will appear here.")
    }
}
