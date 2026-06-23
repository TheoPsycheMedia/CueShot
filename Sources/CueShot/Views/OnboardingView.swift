import Combine
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: AppModel

    private let setupColumns = [GridItem(.adaptive(minimum: 135), spacing: 8)]
    private let permissionRefreshTimer = Timer.publish(every: 1.2, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            let panelWidth = min(max(geometry.size.width - 48, 380), 700)
            let panelHeight = min(max(geometry.size.height - 48, 440), 760)

            ZStack {
                Color.black.opacity(0.38)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 16) {
                            header
                            setupSummary
                            OnboardingPermissionRow(model: model)
                            OnboardingModeRow()
                            OnboardingLocalRow()
                        }
                        .padding(22)
                    }

                    actionRow
                        .padding(.horizontal, 22)
                        .padding(.top, 12)
                        .padding(.bottom, 18)
                        .background(CueColor.surfaceBase.opacity(0.48))
                }
                .frame(width: panelWidth, height: panelHeight)
                .cueGlass(cornerRadius: 28)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(CueColor.reticle.opacity(0.18), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: .black.opacity(0.38), radius: 40, y: 24)
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.985)))
        .onAppear {
            model.refreshPermissions()
        }
        .onReceive(permissionRefreshTimer) { _ in
            guard model.showOnboarding else { return }
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

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Set up CueShot")
                        .font(.system(size: 22, weight: .semibold))
                    setupStatusPill
                }

                Text("CueShot needs two macOS permissions before capture works: Screen Recording for pixels and Accessibility for the click listener and element bounds. Automation is optional for visible paste into Codex.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button {
                model.closeOnboarding()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .cueGlass(cornerRadius: 14, interactive: true)
            .help(model.permissions.capturePermissionsGranted ? "Close onboarding" : "Finish setup later")
            .accessibilityLabel(model.permissions.capturePermissionsGranted ? "Close onboarding" : "Finish setup later")
        }
    }

    private var setupStatusPill: some View {
        Label(
            model.permissions.capturePermissionsGranted ? "Ready" : "Setup needed",
            systemImage: model.permissions.capturePermissionsGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        )
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(model.permissions.capturePermissionsGranted ? CueColor.reticle : .orange)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.white.opacity(0.07), in: Capsule())
        .accessibilityLabel(model.permissions.capturePermissionsGranted ? "Setup ready" : "Setup needed")
    }

    private var setupSummary: some View {
        OnboardingBand(systemImage: "checklist", title: "First-launch setup") {
            VStack(alignment: .leading, spacing: 8) {
                LazyVGrid(columns: setupColumns, alignment: .leading, spacing: 8) {
                    LocalChip(title: "1. Grant Screen", systemImage: model.permissions.screenRecordingGranted ? "checkmark.circle.fill" : "rectangle.on.rectangle")
                    LocalChip(title: "2. Grant Accessibility", systemImage: model.permissions.accessibilityGranted ? "checkmark.circle.fill" : "cursorarrow.motionlines")
                    LocalChip(title: "3. Start Capturing", systemImage: "scope")
                }
                Text("macOS owns the permission prompts. CueShot opens the right pane, refreshes this checklist, and keeps setup visible until the required grants are finished.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        if model.permissions.capturePermissionsGranted {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    finishSetupButton
                    showFloatingControlButton
                }

                VStack(spacing: 10) {
                    finishSetupButton
                    showFloatingControlButton
                }
            }
            .font(.system(size: 13, weight: .medium))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("Finish the required permissions to unlock capture. Automation can wait.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        finishLaterButton
                        checkAgainButton
                        openNextPermissionButton
                    }

                    VStack(spacing: 10) {
                        openNextPermissionButton
                        checkAgainButton
                        finishLaterButton
                    }
                }
                .font(.system(size: 13, weight: .medium))
            }
        }
    }

    private var finishSetupButton: some View {
        Button {
            model.completeOnboarding()
        } label: {
            Text("Finish Setup")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableMotionStyle())
        .cueGlass(cornerRadius: 14, interactive: true)
        .accessibilityHint("Closes onboarding and keeps CueShot ready.")
    }

    private var showFloatingControlButton: some View {
        Button {
            model.completeOnboarding(startCapture: true)
        } label: {
            Label("Show Floating Control", systemImage: "scope")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableMotionStyle())
        .cueTintedGlass(CueColor.reticle.opacity(0.24), cornerRadius: 14, interactive: true)
        .accessibilityHint("Closes onboarding and shows the floating capture control.")
    }

    private var finishLaterButton: some View {
        Button {
            model.dismissOnboardingForNow()
        } label: {
            Text("Finish Later")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableMotionStyle())
        .cueGlass(cornerRadius: 14, interactive: true)
        .accessibilityHint("Hides setup for this session. CueShot will show it again next launch.")
    }

    private var checkAgainButton: some View {
        Button {
            model.refreshPermissions()
        } label: {
            Label("Check Again", systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableMotionStyle())
        .cueGlass(cornerRadius: 14, interactive: true)
        .accessibilityHint("Refreshes the current macOS permission status.")
    }

    private var openNextPermissionButton: some View {
        Button {
            model.openNextRequiredPermission()
        } label: {
            Label(model.permissions.firstMissingRequiredKind?.onboardingActionTitle ?? "Open Permission", systemImage: "arrow.up.forward.app")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableMotionStyle())
        .cueTintedGlass(CueColor.reticle.opacity(0.24), cornerRadius: 14, interactive: true)
        .accessibilityHint("Opens the next required macOS privacy permission.")
    }
}

private struct OnboardingPermissionRow: View {
    @ObservedObject var model: AppModel

    var body: some View {
        OnboardingBand(systemImage: "lock.shield", title: "Permissions") {
            VStack(spacing: 8) {
                PermissionSetupCard(model: model, kind: .screenRecording)
                PermissionSetupCard(model: model, kind: .accessibility)
                PermissionSetupCard(model: model, kind: .automation)
            }
        }
    }
}

private struct PermissionSetupCard: View {
    @ObservedObject var model: AppModel
    let kind: PermissionKind

    private var granted: Bool {
        model.permissions.isGranted(kind)
    }

    private var statusText: String {
        if granted {
            return "Granted"
        }
        if kind.isRequiredForCapture {
            return "Required"
        }
        switch model.permissions.automationStatus {
        case .denied:
            return "Denied"
        case .unknown:
            return "Check"
        case .notDetermined:
            return "Optional"
        case .granted:
            return "Granted"
        }
    }

    private var statusColor: Color {
        if granted {
            return CueColor.reticle
        }
        return kind.isRequiredForCapture ? .orange : .secondary
    }

    var body: some View {
        HStack(alignment: .center, spacing: 11) {
            Image(systemName: granted ? "checkmark.circle.fill" : kind.onboardingSystemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(width: 28, height: 28)
                .cueTintedGlass(statusColor.opacity(0.14), cornerRadius: 10)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(kind.title)
                        .font(.system(size: 13, weight: .semibold))
                    PermissionStatusBadge(title: statusText, color: statusColor)
                }

                Text(kind.onboardingDetail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button {
                model.openPermissionSettings(kind)
            } label: {
                Label(granted ? "Granted" : kind.onboardingActionTitle, systemImage: granted ? "checkmark" : "arrow.up.forward.app")
                    .labelStyle(.titleAndIcon)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(minWidth: 132)
            }
            .font(.system(size: 11, weight: .medium))
            .buttonStyle(PressableMotionStyle())
            .cueGlass(cornerRadius: 12, interactive: !granted)
            .disabled(granted)
            .accessibilityHint(granted ? "This permission is already enabled." : "Opens macOS System Settings for this permission.")
        }
        .padding(12)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kind.title), \(statusText)")
    }
}

private struct PermissionStatusBadge: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }
}

private struct OnboardingModeRow: View {
    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 8)]

    var body: some View {
        OnboardingBand(systemImage: "rectangle.dashed", title: "Pick the capture shape") {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ModeChip(title: "Element", detail: "Exact", systemImage: "scope")
                ModeChip(title: "Selection", detail: "Estimated", systemImage: "cursorarrow.rays")
                ModeChip(title: "Area", detail: "Drag", systemImage: "selection.pin.in.out")
                ModeChip(title: "Window", detail: "Click", systemImage: "macwindow")
                ModeChip(title: "Screen", detail: "Display", systemImage: "display")
                ModeChip(title: "OCR", detail: "Extract text", systemImage: "text.viewfinder")
            }
        }
    }
}

private struct OnboardingLocalRow: View {
    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 8)]

    var body: some View {
        OnboardingBand(systemImage: "internaldrive", title: "Keep the loop local") {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                LocalChip(title: "PNG history", systemImage: "clock.arrow.circlepath")
                LocalChip(title: "Clipboard preview", systemImage: "doc.on.clipboard")
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(detail)")
    }
}

private struct LocalChip: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 11, weight: .medium))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.white.opacity(0.07), in: Capsule())
            .accessibilityLabel(title)
    }
}
