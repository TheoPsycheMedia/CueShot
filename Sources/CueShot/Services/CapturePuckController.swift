import AppKit
import SwiftUI

@MainActor
final class CapturePuckController {
    private var panel: NSPanel?

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
        guard let panel else { return false }

        let frame = panel.frame.insetBy(dx: -8, dy: -8)
        if frame.contains(point) {
            return true
        }

        guard let screenFrame = panel.screen?.frame ?? NSScreen.main?.frame else {
            return false
        }

        let flippedPoint = CGPoint(
            x: point.x,
            y: screenFrame.maxY - (point.y - screenFrame.minY)
        )
        return frame.contains(flippedPoint)
    }

    private func makePanel(model: AppModel) -> NSPanel {
        let panel = FloatingCapturePanel(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 392, height: 82)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = NSHostingView(rootView: CapturePuckView(model: model))
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
                .frame(width: 156, alignment: .leading)

                Spacer(minLength: 0)

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

                Menu {
                    Button("Hide Button") {
                        model.hideCapturePuck()
                    }
                    Button("Open CueShot") {
                        model.openMainWindow()
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
                .menuStyle(.button)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: 392, height: 82)
            .cueGlass(cornerRadius: 24, interactive: true)
            .scaleEffect(appeared ? 1 : 0.96)
            .opacity(appeared ? 1 : 0)
            .animation(MotionSpec.entrance, value: appeared)
            .onAppear { appeared = true }
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
