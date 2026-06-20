import AppKit
import SwiftUI

@MainActor
final class OverlayWindowController {
    private let model = OverlayViewModel()
    private var panels: [NSPanel] = []

    func show() {
        guard panels.isEmpty else { return }

        panels = NSScreen.screens.map { screen in
            let panel = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false,
                screen: screen
            )

            panel.level = .statusBar
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.contentView = NSHostingView(rootView: CaptureOverlayPanelView(model: model, screenFrame: screen.frame))
            panel.orderFrontRegardless()
            return panel
        }
    }

    func update(target: CaptureTarget?, state: CaptureState) {
        show()
        model.snapshot = OverlaySnapshot(target: target, state: state)
    }

    func hide() {
        panels.forEach { $0.orderOut(nil) }
        panels.removeAll()
        model.snapshot = nil
    }
}
@MainActor
private final class OverlayViewModel: ObservableObject {
    @Published var snapshot: OverlaySnapshot?
}

private struct OverlaySnapshot: Equatable {
    let target: CaptureTarget?
    let state: CaptureState
}

private struct CaptureOverlayPanelView: View {
    @ObservedObject var model: OverlayViewModel
    let screenFrame: CGRect

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let snapshot = model.snapshot, let target = snapshot.target {
                    if snapshot.state == .capturing {
                        Color.black.opacity(0.10)
                            .transition(.opacity)
                    }

                    let rect = localRect(for: target.rect, in: geometry.size)
                    let point = localPoint(for: target.point, in: geometry.size)

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(CueColor.reticle.opacity(snapshot.state == .capturing ? 1 : 0.92), lineWidth: 1.5)
                        .frame(width: max(rect.width, 1), height: max(rect.height, 1))
                        .position(x: rect.midX, y: rect.midY)
                        .shadow(color: CueColor.reticle.opacity(0.38), radius: 10)

                    ReticleOverlay()
                        .position(point)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(target.dimensionsText)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        Text(target.metadataLabel)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .cueTintedGlass(CueColor.reticle.opacity(0.16), cornerRadius: 10)
                    .position(x: rect.minX + 74, y: max(18, rect.minY - 18))
                }
            }
            .animation(MotionSpec.captureSpring, value: model.snapshot)
        }
    }

    private func localRect(for rect: CGRect, in size: CGSize) -> CGRect {
        CGRect(
            x: rect.minX - screenFrame.minX,
            y: rect.minY - screenFrame.minY,
            width: rect.width,
            height: rect.height
        )
        .intersection(CGRect(origin: .zero, size: size))
    }

    private func localPoint(for point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(point.x - screenFrame.minX, 0), size.width),
            y: min(max(point.y - screenFrame.minY, 0), size.height)
        )
    }
}

private struct ReticleOverlay: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(CueColor.reticle)
                .frame(width: 5, height: 5)
            Rectangle()
                .fill(CueColor.reticle)
                .frame(width: 44, height: 1.5)
            Rectangle()
                .fill(CueColor.reticle)
                .frame(width: 1.5, height: 44)
        }
        .shadow(color: CueColor.reticle.opacity(0.32), radius: 8)
    }
}
