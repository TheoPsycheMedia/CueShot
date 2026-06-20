import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.38)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                header

                VStack(spacing: 10) {
                    OnboardingLoopRow()
                    OnboardingModeRow()
                    OnboardingPermissionRow(model: model)
                    OnboardingLocalRow()
                }

                HStack(spacing: 10) {
                    Button {
                        model.completeOnboarding()
                    } label: {
                        Text("Done")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PressableMotionStyle())
                    .cueGlass(cornerRadius: 14, interactive: true)

                    Button {
                        model.completeOnboarding(startCapture: true)
                    } label: {
                        Label("Show Floating Control", systemImage: "scope")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PressableMotionStyle())
                    .cueTintedGlass(CueColor.reticle.opacity(0.24), cornerRadius: 14, interactive: true)
                }
                .font(.system(size: 13, weight: .medium))
            }
            .padding(22)
            .frame(width: 620)
            .cueGlass(cornerRadius: 28)
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(CueColor.reticle.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.38), radius: 40, y: 24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.985)))
        .onAppear {
            model.refreshPermissions()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(CueColor.reticle.opacity(0.16))
                    .frame(width: 52, height: 52)
                Image(systemName: "scope")
                    .font(.system(size: 24, weight: .regular))
                    .foregroundStyle(CueColor.reticle)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Set up CueShot")
                    .font(.system(size: 22, weight: .semibold))
                Text("Choose a capture type, arm the floating control, then click or drag. CueShot saves a PNG and sends or copies it to Codex.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button {
                model.completeOnboarding()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .cueGlass(cornerRadius: 14, interactive: true)
            .help("Close onboarding")
        }
    }
}

private struct OnboardingLoopRow: View {
    var body: some View {
        OnboardingBand(systemImage: "scope", title: "The loop") {
            HStack(spacing: 8) {
                LocalChip(title: "Choose type", systemImage: "rectangle.grid.1x2")
                LocalChip(title: "Arm control", systemImage: "scope")
                LocalChip(title: "Click or drag", systemImage: "cursorarrow.click")
                LocalChip(title: "Sent or copied", systemImage: "paperplane")
            }
        }
    }
}

private struct OnboardingModeRow: View {
    var body: some View {
        OnboardingBand(systemImage: "rectangle.dashed", title: "Pick the capture shape") {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ModeChip(title: "Element", detail: "Exact", systemImage: "scope")
                    ModeChip(title: "Selection", detail: "Estimated click", systemImage: "cursorarrow.rays")
                    ModeChip(title: "Area", detail: "Drag region", systemImage: "selection.pin.in.out")
                }
                HStack(spacing: 8) {
                    ModeChip(title: "Window", detail: "Click window", systemImage: "macwindow")
                    ModeChip(title: "Screen", detail: "Click display", systemImage: "display")
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

private struct OnboardingPermissionRow: View {
    @ObservedObject var model: AppModel

    var body: some View {
        OnboardingBand(systemImage: "lock.shield", title: "Grant only what CueShot needs") {
            VStack(spacing: 8) {
                PermissionSetupLine(
                    title: "Screen Recording",
                    granted: model.permissions.screenRecordingGranted,
                    action: { model.openPermissionSettings(.screenRecording) }
                )
                PermissionSetupLine(
                    title: "Accessibility",
                    granted: model.permissions.accessibilityGranted,
                    action: { model.openPermissionSettings(.accessibility) }
                )
            }
        }
    }
}

private struct OnboardingLocalRow: View {
    var body: some View {
        OnboardingBand(systemImage: "internaldrive", title: "Keep the loop local") {
            HStack(spacing: 8) {
                LocalChip(title: "PNG history", systemImage: "clock.arrow.circlepath")
                LocalChip(title: "Clipboard fallback", systemImage: "doc.on.clipboard")
                LocalChip(title: "No cloud sync", systemImage: "wifi.slash")
            }
        }
    }
}

private struct OnboardingBand<Content: View>: View {
    let systemImage: String
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(CueColor.reticle)
                .frame(width: 28, height: 28)
                .cueTintedGlass(CueColor.reticle.opacity(0.14), cornerRadius: 10)

            VStack(alignment: .leading, spacing: 9) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                content()
            }

            Spacer(minLength: 0)
        }
        .padding(13)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct ModeChip: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(detail)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

private struct PermissionSetupLine: View {
    let title: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(granted ? CueColor.reticle : .orange)
            Text(title)
                .font(.system(size: 12, weight: .medium))
            Spacer()
            Button(granted ? "Granted" : "Open") {
                action()
            }
            .font(.system(size: 11, weight: .medium))
            .disabled(granted)
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.white.opacity(granted ? 0.045 : 0.10), in: Capsule())
        }
    }
}

private struct LocalChip: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 11, weight: .medium))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.white.opacity(0.07), in: Capsule())
    }
}
