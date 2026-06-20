import SwiftUI

struct StatusMenuLabel: View {
    let state: CaptureState

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "scope")
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(state.label)
        }
    }

    private var statusColor: Color {
        switch state {
        case .permissionNeeded:
            .orange
        case .copyFallback, .codexNotFocused:
            .yellow
        default:
            CueColor.reticle
        }
    }
}

struct MenuBarPopoverView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Label("CueShot", systemImage: "scope")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                StatusPill(state: model.captureState)
            }

            MiniLens(model: model)

            VStack(spacing: 10) {
                CaptureControlRow(model: model)
                PermissionSummary(model: model)
                RecentStrip(model: model)
            }

            HStack(spacing: 10) {
                Button("Open CueShot") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(PressableMotionStyle())
                .cueGlass(cornerRadius: 13, interactive: true)

                Button("Copy Last PNG") {
                    model.copyLastCapture()
                }
                .buttonStyle(PressableMotionStyle())
                .cueGlass(cornerRadius: 13, interactive: true)
            }
        }
        .padding(16)
    }
}

struct StatusPill: View {
    let state: CaptureState

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(state.label)
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .cueTintedGlass(color.opacity(0.18), cornerRadius: 14)
    }

    private var color: Color {
        switch state {
        case .permissionNeeded:
            .orange
        case .copyFallback, .codexNotFocused:
            .yellow
        default:
            CueColor.reticle
        }
    }
}

private struct CaptureControlRow: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            Button {
                model.toggleCapturePuck()
            } label: {
                Label(model.capturePuckVisible ? "Hide Control" : "Show Control", systemImage: model.capturePuckVisible ? "eye.slash" : "scope")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PressableMotionStyle())
            .cueGlass(cornerRadius: 14, interactive: true)

            Button {
                model.copyLastCapture()
            } label: {
                Label("Copy PNG", systemImage: "doc.on.clipboard")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PressableMotionStyle())
            .cueGlass(cornerRadius: 14, interactive: true)
            .disabled(model.selectedCapture == nil)
        }
    }
}

private struct MiniLens: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.black.opacity(0.20))
            if let image = model.selectedCaptureImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(12)
            } else {
                TargetOutline(active: model.captureState.isActive)
                    .frame(width: 136, height: 64)
                Image(systemName: "scope")
                    .font(.system(size: 22))
                    .foregroundStyle(CueColor.reticle)
            }

            Text(model.currentTarget?.dimensionsText ?? model.selectedCapture?.dimensions ?? "Ready")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .cueTintedGlass(CueColor.reticle.opacity(0.18), cornerRadius: 10)
                .offset(x: 86, y: -56)
        }
        .frame(height: 174)
        .cueGlass(cornerRadius: 24)
    }
}

private struct PermissionSummary: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack {
            Label("Accessibility", systemImage: model.permissions.accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
            Spacer()
            Label("Screen", systemImage: model.permissions.screenRecordingGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(12)
        .cueGlass(cornerRadius: 16)
    }
}

private struct RecentStrip: View {
    @ObservedObject var model: AppModel

    var body: some View {
        if model.recentCaptures.isEmpty {
            Text("Show the floating control to add a PNG")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 58)
                .cueGlass(cornerRadius: 14)
        } else {
            HStack(spacing: 8) {
                ForEach(model.recentCaptures.prefix(3)) { capture in
                    Button {
                        model.selectedCaptureID = capture.id
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: capture.mode.symbol)
                            Text(capture.dimensions)
                                .font(.system(size: 9, design: .monospaced))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(PressableMotionStyle())
                    .background(.white.opacity(capture.id == model.selectedCaptureID ? 0.16 : 0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .frame(height: 58)
        }
    }
}
