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
                    CueGlassGroup(spacing: 16) {
                        VStack(spacing: 12) {
                            WindowHeader(model: model)

                            HStack(alignment: .top, spacing: 12) {
                                MotionElement(delay: 0.04) {
                                    ModeRail(model: model)
                                        .frame(width: 86)
                                }

                                MotionElement(delay: 0.10) {
                                    CaptureLensView(model: model)
                                        .frame(minWidth: 410, idealWidth: 500, maxWidth: .infinity)
                                }

                                MotionElement(delay: 0.16) {
                                    InspectorView(model: model)
                                        .frame(width: 270)
                                }
                            }
                            .frame(maxHeight: .infinity, alignment: .top)
                        }
                        .padding(16)
                        .frame(
                            width: max(0, geometry.size.width - 36),
                            height: max(0, geometry.size.height - 36),
                            alignment: .top
                        )
                        .cueGlass(cornerRadius: CueShape.panelRadius)
                        .shadow(color: .black.opacity(0.24), radius: 34, y: 18)
                    }
                    .padding(18)
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
                colors: [
                    Color(red: 0.08, green: 0.09, blue: 0.10),
                    Color(red: 0.16, green: 0.17, blue: 0.16),
                    Color(red: 0.10, green: 0.12, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.white.opacity(0.08))
                .frame(width: 520, height: 320)
                .offset(x: -190, y: -90)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(CueColor.reticle.opacity(0.08))
                .frame(width: 440, height: 260)
                .offset(x: 260, y: 120)
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
