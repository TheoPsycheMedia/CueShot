import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack {
            AmbientDesktopBackdrop()

            if model.showOnboarding {
                OnboardingView(model: model)
                    .zIndex(10)
            } else {
                GeometryReader { geometry in
                    CueGlassGroup(spacing: 12) {
                        VStack(spacing: 10) {
                            WindowHeader(model: model)

                            HStack(alignment: .top, spacing: 10) {
                                MotionElement(delay: 0.06) {
                                    CaptureLensView(model: model)
                                        .frame(minWidth: 430, idealWidth: 520, maxWidth: .infinity)
                                }

                                MotionElement(delay: 0.12) {
                                    InspectorView(model: model)
                                        .frame(width: 240)
                                }
                            }
                            .frame(maxHeight: .infinity, alignment: .top)
                        }
                        .padding(12)
                        .frame(
                            width: max(0, geometry.size.width - 28),
                            height: max(0, geometry.size.height - 28),
                            alignment: .top
                        )
                        .cueGlass(cornerRadius: 22)
                        .shadow(color: .black.opacity(0.20), radius: 26, y: 14)
                    }
                    .padding(14)
                }
            }
        }
        .onAppear {
            model.applyLaunchPreferences()
        }
    }
}

private struct AmbientDesktopBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: CueColor.backdrop,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(CueColor.glow.opacity(0.08))
                .frame(width: 420, height: 260)
                .offset(x: -180, y: -100)
        }
        .ignoresSafeArea()
    }
}

private struct WindowHeader: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            Label("CueShot", systemImage: "scope")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                model.openOnboarding()
            } label: {
                Label("Onboarding", systemImage: "questionmark.circle")
                    .labelStyle(.titleAndIcon)
            }
            .font(.system(size: 12, weight: .medium))
            .buttonStyle(PressableMotionStyle())
            .cueGlass(cornerRadius: 12, interactive: true)
            .help("Open CueShot onboarding")
            .accessibilityLabel("Onboarding")
            .accessibilityHint("Shows the capture workflow, permissions, and setup steps.")

            Button {
                model.openSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .labelStyle(.titleAndIcon)
            }
            .font(.system(size: 12, weight: .medium))
            .buttonStyle(PressableMotionStyle())
            .cueGlass(cornerRadius: 12, interactive: true)
            .help("Open CueShot settings")
            .accessibilityLabel("Settings")
            .accessibilityHint("Opens capture, output, resize key, permission, and history settings.")

            StatusPill(state: model.captureState)
        }
        .padding(.horizontal, 2)
    }
}
