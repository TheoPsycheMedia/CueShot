import SwiftUI

struct CaptureLensView: View {
    @ObservedObject var model: AppModel
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 14) {
            ModeHeader(model: model)

            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.black.opacity(0.20))
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                    }

                if let target = model.currentTarget, model.captureState.isActive {
                    LiveTargetPlate(target: target)
                        .padding(24)
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))

                    TargetOutline(active: true)
                        .frame(
                            width: min(max(target.rect.width * 0.34, 96), 218),
                            height: min(max(target.rect.height * 0.34, 52), 128)
                        )
                        .offset(x: 18, y: 8)

                    ReticleView(active: true)
                        .scaleEffect(pulse ? 1.035 : 1)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                } else if let image = model.selectedCaptureImage {
                    CapturedImagePlate(image: image, record: model.selectedCapture)
                        .padding(18)
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                } else {
                    EmptyLensPlate(mode: model.selectedMode)
                        .padding(24)
                        .transition(.opacity.combined(with: .scale(scale: 0.985)))
                }
            }
            .frame(minHeight: 290)
            .cueGlass(cornerRadius: 28)

            LensActionRow(model: model)
        }
        .padding(16)
        .cueGlass(cornerRadius: 26)
        .onAppear {
            pulse = true
        }
    }
}

private struct ModeHeader: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.08))
                    .frame(width: 44, height: 44)
                Image(systemName: model.selectedMode.symbol)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(model.captureState.isActive ? CueColor.reticle : .primary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("\(model.selectedMode.title) - \(model.selectedMode.methodTitle)")
                    .font(.system(size: 18, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(model.captureState.isActive ? model.captureState.detail : model.selectedMode.idleInstruction)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .layoutPriority(1)

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                StatusPill(state: model.captureState)
            }
        }
    }
}

private struct LensActionRow: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            Button {
                model.toggleCapturePuck()
            } label: {
                Label(model.capturePuckVisible ? "Hide Floating Control" : "Show Floating Control", systemImage: model.capturePuckVisible ? "eye.slash" : "scope")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PressableMotionStyle())
            .cueGlass(cornerRadius: 14, interactive: true)

            if model.selectedCapture != nil {
                Button {
                    model.copyLastCapture()
                } label: {
                    Label("Copy PNG", systemImage: "doc.on.clipboard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PressableMotionStyle())
                .cueGlass(cornerRadius: 14, interactive: true)

                Button {
                    model.saveSelectedCaptureAs()
                } label: {
                    Label("Save As", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PressableMotionStyle())
                .cueGlass(cornerRadius: 14, interactive: true)
            }
        }
    }
}

private struct EmptyLensPlate: View {
    let mode: CaptureMode

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(CueColor.reticle.opacity(0.22), lineWidth: 1)
                    .frame(width: 82, height: 82)
                Image(systemName: mode.symbol)
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(CueColor.reticle)
            }

            VStack(spacing: 5) {
                Text("Ready for \(mode.title)")
                    .font(.system(size: 15, weight: .semibold))
                Text(mode.idleInstruction)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                StepPill(index: "1", title: "Choose mode")
                StepPill(index: "2", title: "Arm control")
                StepPill(index: "3", title: mode == .area ? "Drag" : "Click")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(18)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct StepPill: View {
    let index: String
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Text(index)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .frame(width: 16, height: 16)
                .background(CueColor.pearl, in: Circle())
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(.white.opacity(0.07), in: Capsule())
    }
}

private struct LiveTargetPlate: View {
    let target: CaptureTarget

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live target")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(CueColor.reticle)
                    Text(target.metadataLabel)
                        .font(.system(size: 13, weight: .semibold))
                    Text(target.confidence.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(target.dimensionsText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(CueColor.reticle.opacity(0.14))
                    .frame(width: 92, height: 72)
                    .overlay {
                        Image(systemName: "scope")
                            .font(.system(size: 22))
                            .foregroundStyle(CueColor.reticle)
                    }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Release and CueShot will save the PNG, copy it, and show it in the floating preview.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
        }
        .padding(18)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct CapturedImagePlate: View {
    let image: NSImage
    let record: CaptureRecord?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                }

            if let record {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Last capture")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(CueColor.reticle)
                    HStack(spacing: 8) {
                        Image(systemName: record.mode.symbol)
                        Text(record.sourceAppName)
                        Text(record.dimensions)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .cueGlass(cornerRadius: 13)
                .padding(10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct TargetOutline: View {
    let active: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(CueColor.reticle.opacity(active ? 1 : 0.62), style: StrokeStyle(lineWidth: 1.6, dash: [8, 7]))
            .shadow(color: CueColor.reticle.opacity(active ? 0.4 : 0.18), radius: 10)
    }
}

private struct ReticleView: View {
    let active: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(CueColor.reticle.opacity(active ? 1 : 0.65))
                .frame(width: 5, height: 5)

            Rectangle()
                .fill(CueColor.reticle.opacity(active ? 1 : 0.65))
                .frame(width: 44, height: 1.4)

            Rectangle()
                .fill(CueColor.reticle.opacity(active ? 1 : 0.65))
                .frame(width: 1.4, height: 44)
        }
        .accessibilityHidden(true)
    }
}
