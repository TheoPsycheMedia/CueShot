import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var confirmClearHistory = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    CueColor.graphite,
                    Color(red: 0.12, green: 0.13, blue: 0.13),
                    CueColor.surfaceBase
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 14) {
                    SettingsHeader()

                    SettingsSection(
                        title: "Capture",
                        detail: "Choose the default mode and how the floating control appears."
                    ) {
                        SettingsRow(title: "Default capture type", detail: model.selectedMode.helpText) {
                            Picker("", selection: $model.selectedMode) {
                                ForEach(CaptureMode.allCases) { mode in
                                    Label("\(mode.title) - \(mode.methodTitle)", systemImage: mode.symbol)
                                        .tag(mode)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 240)
                        }

                        Toggle("Show floating control when CueShot opens", isOn: $model.showCaptureButtonAtLaunch)

                        Toggle("Launch CueShot at login", isOn: Binding(
                            get: { model.launchAtLoginEnabled },
                            set: { model.setLaunchAtLogin($0) }
                        ))
                    }

                    SettingsSection(
                        title: "Output",
                        detail: "PNG stays local. CueShot sends to Codex only when available."
                    ) {
                        Toggle("Send to Codex when available", isOn: $model.autoPasteToCodex)

                        SettingsValueRow(title: "Fallback", value: "Copy PNG")
                        SettingsValueRow(title: "Format", value: "PNG")

                        VStack(alignment: .leading, spacing: 6) {
                            Text("File naming template")
                                .font(.system(size: 12, weight: .medium))
                            TextField("CueShot-{app}-{mode}-{date}", text: $model.fileNameTemplate)
                                .textFieldStyle(.roundedBorder)
                            Text("Tokens: {app}, {mode}, {date}, {size}")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }

                    SettingsSection(
                        title: "History",
                        detail: "Local captures are pruned to the latest 30 records."
                    ) {
                        SettingsValueRow(title: "Location", value: "~/Library/Application Support/CueShot/History")
                        HStack(spacing: 8) {
                            Button {
                                model.revealHistoryFolder()
                            } label: {
                                Label("Reveal Folder", systemImage: "folder")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PressableMotionStyle())
                            .cueGlass(cornerRadius: 12, interactive: true)

                            Button(role: .destructive) {
                                confirmClearHistory = true
                            } label: {
                                Label("Clear History", systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PressableMotionStyle())
                            .cueGlass(cornerRadius: 12, interactive: true)
                        }
                    }

                    SettingsSection(
                        title: "Shortcuts",
                        detail: "Keyboard commands keep capture fast without guessing."
                    ) {
                        ShortcutRow(title: "Show capture control", shortcut: "Shift Command 1")
                        ShortcutRow(title: "Show or hide floating control", shortcut: "Shift Command B")
                        ShortcutRow(title: "Cancel capture", shortcut: "Esc")
                        ShortcutRow(title: "Copy last PNG", shortcut: "Shift Command C")
                    }

                    SettingsSection(
                        title: "Privacy",
                        detail: "CueShot captures visible pixels locally and uses Accessibility for exact element bounds."
                    ) {
                        PermissionSettingsRow(title: "Element detection", detail: "Uses Accessibility", granted: model.permissions.accessibilityGranted) {
                            model.openPermissionSettings(.accessibility)
                        }
                        PermissionSettingsRow(title: "Screen capture", detail: "Uses Screen Recording", granted: model.permissions.screenRecordingGranted) {
                            model.openPermissionSettings(.screenRecording)
                        }

                        HStack(spacing: 8) {
                            Button {
                                model.refreshPermissions()
                            } label: {
                                Label("Refresh", systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PressableMotionStyle())
                            .cueGlass(cornerRadius: 12, interactive: true)

                            Button {
                                model.showOnboardingAgain()
                                model.openMainWindow()
                            } label: {
                                Label("Onboarding", systemImage: "sparkles")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PressableMotionStyle())
                            .cueGlass(cornerRadius: 12, interactive: true)
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 640, height: 680)
        .onAppear {
            model.refreshPermissions()
            model.refreshLaunchAtLoginStatus()
        }
        .confirmationDialog("Clear all capture history?", isPresented: $confirmClearHistory) {
            Button("Clear History", role: .destructive) {
                model.clearHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes saved CueShot PNGs and the local history manifest.")
        }
    }
}

private struct SettingsHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "scope")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(CueColor.reticle)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("CueShot Settings")
                    .font(.system(size: 20, weight: .semibold))
                Text("Capture behavior, handoff, history, and privacy.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let detail: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
        }
        .padding(14)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.09), lineWidth: 1)
        }
    }
}

private struct SettingsRow<Content: View>: View {
    let title: String
    let detail: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)
            content()
        }
    }
}

private struct SettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

private struct ShortcutRow: View {
    let title: String
    let shortcut: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
            Spacer()
            Text(shortcut)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

private struct PermissionSettingsRow: View {
    let title: String
    let detail: String
    let granted: Bool
    let open: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(granted ? CueColor.reticle : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if granted {
                Text("Granted")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(CueColor.reticle)
            } else {
                Button("Open") {
                    open()
                }
                .font(.system(size: 11, weight: .medium))
                .buttonStyle(.plain)
            }
        }
    }
}
