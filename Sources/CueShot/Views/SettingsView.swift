import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var confirmClearHistory = false
    @State private var shortcutSearch = ""
    @FocusState private var focusedField: SettingsFocusField?

    private var visibleShortcutCommands: [CueShotCommand] {
        let query = shortcutSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return CueShotCommand.commandCenterOrder
        }

        return CueShotCommand.commandCenterOrder.filter { command in
            command.title.lowercased().contains(query)
                || command.detail.lowercased().contains(query)
                || command.groupTitle.lowercased().contains(query)
                || model.shortcut(for: command).displayText.lowercased().contains(query)
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    CueColor.graphite,
                    CueColor.glow.opacity(0.20),
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
                        title: "Appearance",
                        detail: "Change CueShot's color mood across the capture control, reticle, overlay, and settings."
                    ) {
                        ThemeMoodPicker(model: model)

                        Button {
                            model.cycleTheme()
                        } label: {
                            Label("Change Color Mood", systemImage: "paintpalette")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PressableMotionStyle())
                        .cueTintedGlass(CueColor.reticle.opacity(0.16), cornerRadius: 12, interactive: true)
                        .help("Cycle through CueShot color moods")
                    }

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
                        detail: "Clipboard-first by default. Capture, preview, then paste or drag the PNG into Codex."
                    ) {
                        SettingsValueRow(title: "Primary behavior", value: "Copy PNG to Clipboard")
                        Text("After capture, the floating control shows the last PNG. Press Cmd+V in Codex, drag the preview, or reveal it in Finder.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        SettingsValueRow(title: "Format", value: "PNG")

                        VStack(alignment: .leading, spacing: 6) {
                            Text("File naming template")
                                .font(.system(size: 12, weight: .medium))
                            TextField("CueShot-{app}-{mode}-{date}", text: $model.fileNameTemplate)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: .fileNameTemplate)
                            Text("Tokens: {app}, {mode}, {date}, {size}")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }

                    SettingsSection(
                        title: "Advanced",
                        detail: "Experimental Codex App Server can create a new App Server thread, but it is not the primary visible-composer handoff."
                    ) {
                        Toggle("Try Codex App Server after copying", isOn: $model.autoPasteToCodex)

                        SettingsValueRow(title: "Resolved Codex CLI", value: model.codexCLIResolutionSummary)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Codex CLI path override")
                                .font(.system(size: 12, weight: .medium))
                            TextField("/opt/homebrew/bin/codex", text: $model.codexCLIPathOverride)
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: .codexCLIPathOverride)
                            Text("Leave blank to check /opt/homebrew/bin, /usr/local/bin, ~/.local/bin, then PATH.")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }

                        SettingsValueRow(title: "Last App Server handoff", value: model.handoffStatusSummary)
                        SettingsDiagnosticBlock(title: "App Server diagnostic", value: model.appServerDiagnosticSummary)

                        Button {
                            model.testCodexHandoff()
                        } label: {
                            Label("Test App Server Handoff", systemImage: "arrow.clockwise.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PressableMotionStyle())
                        .cueGlass(cornerRadius: 12, interactive: true)
                        .help("Generate a sample PNG and run a live experimental Codex App Server localImage handoff test.")
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
                        title: "Command Center",
                        detail: "Search CueShot commands, pick a key, and change modifiers without memorizing defaults."
                    ) {
                        HStack(spacing: 10) {
                            CommandCenterSearchField(text: $shortcutSearch)

                            Button {
                                model.resetAllShortcuts()
                            } label: {
                                Label("Reset All", systemImage: "arrow.counterclockwise")
                                    .frame(width: 106)
                            }
                            .buttonStyle(PressableMotionStyle())
                            .cueGlass(cornerRadius: 12, interactive: true)
                            .help("Reset every CueShot shortcut to its default keybinding.")
                        }

                        VStack(spacing: 8) {
                            ForEach(visibleShortcutCommands) { command in
                                CommandShortcutRow(model: model, command: command)
                            }

                            if visibleShortcutCommands.isEmpty {
                                Text("No CueShot commands match that search.")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 16)
                            }
                        }
                    }

                    SettingsSection(
                        title: "Resize Keys",
                        detail: "Plain scroll resizes the whole target. Pick modifier keys for one-axis adjustments."
                    ) {
                        SettingsRow(title: "Width resize key", detail: "Hold this key while scrolling to change width.") {
                            ResizeModifierPicker(selection: $model.widthResizeModifier)
                        }

                        SettingsRow(title: "Height resize key", detail: "Hold this key while scrolling to change height.") {
                            ResizeModifierPicker(selection: $model.heightResizeModifier)
                        }

                        SettingsValueRow(title: "Current mapping", value: model.resizeBindingSummary)
                    }

                    SettingsSection(
                        title: "Privacy",
                        detail: "CueShot captures visible pixels locally and uses Accessibility for exact element bounds."
                    ) {
                        PermissionSettingsRow(title: "Capture listener", detail: "Accessibility required", granted: model.permissions.accessibilityGranted) {
                            model.openPermissionSettings(.accessibility)
                        }
                        PermissionSettingsRow(title: "Screen capture", detail: "Uses Screen Recording", granted: model.permissions.screenRecordingGranted) {
                            model.openPermissionSettings(.screenRecording)
                        }
                        SettingsValueRow(title: "Diagnostic", value: model.permissionDiagnosticSummary)
                        Text("After changing macOS privacy settings, quit and reopen CueShot if capture still fails. CueShot keeps PNG capture local and clipboard-first.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

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
        .preferredColorScheme(.dark)
        .onAppear {
            focusedField = nil
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

private struct ThemeMoodPicker: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ThemeSwatch(theme: model.selectedTheme, size: 38)

                VStack(alignment: .leading, spacing: 3) {
                    Text(model.selectedTheme.title)
                        .font(.system(size: 12, weight: .semibold))
                    Text(model.selectedTheme.detail)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Picker("Color mood", selection: $model.selectedTheme) {
                    ForEach(CueTheme.allCases) { theme in
                        Text(theme.title)
                            .tag(theme)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 150)
            }

            HStack(spacing: 8) {
                ForEach(CueTheme.allCases) { theme in
                    Button {
                        model.selectedTheme = theme
                    } label: {
                        VStack(spacing: 5) {
                            ThemeSwatch(theme: theme, size: 30)
                            Text(theme.title)
                                .font(.system(size: 9, weight: .semibold))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PressableMotionStyle())
                    .background(.white.opacity(model.selectedTheme == theme ? 0.10 : 0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder((model.selectedTheme == theme ? theme.primary : .white).opacity(model.selectedTheme == theme ? 0.45 : 0.08), lineWidth: 1)
                    }
                    .accessibilityLabel("\(theme.title) color mood")
                    .accessibilityAddTraits(model.selectedTheme == theme ? [.isSelected] : [])
                }
            }
        }
    }
}

private struct ThemeSwatch: View {
    let theme: CueTheme
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(theme.primary)
                .frame(width: size, height: size)
                .shadow(color: theme.glow.opacity(0.35), radius: 8, y: 2)
            Circle()
                .fill(theme.secondary)
                .frame(width: size * 0.48, height: size * 0.48)
                .offset(x: size * 0.22, y: -size * 0.16)
            Circle()
                .strokeBorder(theme.pearl.opacity(0.72), lineWidth: 1)
                .frame(width: size, height: size)
        }
        .accessibilityHidden(true)
    }
}

private enum SettingsFocusField: Hashable {
    case fileNameTemplate
    case codexCLIPathOverride
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

private struct SettingsDiagnosticBlock: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

private struct CommandCenterSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("Search commands", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium))

            Spacer()

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .cueGlass(cornerRadius: 12, interactive: false)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search CueShot commands")
    }
}

private struct CommandShortcutRow: View {
    @ObservedObject var model: AppModel
    let command: CueShotCommand

    private var shortcut: CueShotShortcut {
        model.shortcut(for: command)
    }

    private var modifierPresetBinding: Binding<CueShortcutModifierPreset> {
        Binding(
            get: {
                CueShortcutModifierPreset.matching(shortcut.modifiers)
            },
            set: { preset in
                model.updateShortcut(for: command) { shortcut in
                    shortcut.modifiers = preset.modifiers
                }
            }
        )
    }

    private var keyBinding: Binding<CueShortcutKey?> {
        Binding(
            get: {
                shortcut.key
            },
            set: { key in
                model.updateShortcut(for: command) { shortcut in
                    shortcut.key = key
                }
            }
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: command.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(CueColor.reticle)
                .frame(width: 34, height: 34)
                .background(CueColor.reticle.opacity(0.11), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(command.title)
                        .font(.system(size: 12, weight: .semibold))
                    Text(command.groupTitle.uppercased())
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.07), in: Capsule())
                }

                Text(command.detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            ShortcutBindingBadge(shortcut: shortcut)

            Picker("Modifiers", selection: modifierPresetBinding) {
                ForEach(CueShortcutModifierPreset.allCases) { preset in
                    Text(preset.title)
                        .tag(preset)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 82)
            .help("Choose modifier keys")

            Picker("Key", selection: keyBinding) {
                Text("Unassigned")
                    .tag(Optional<CueShortcutKey>.none)
                ForEach(CueShortcutKey.allCases) { key in
                    Text(key.displayTitle)
                        .tag(Optional(key))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 96)
            .help("Choose shortcut key")

            Button {
                model.resetShortcut(for: command)
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Reset to default")
            .accessibilityLabel("Reset \(command.title) shortcut")

            Button {
                model.clearShortcut(for: command)
            } label: {
                Image(systemName: "xmark.circle")
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Clear shortcut")
            .accessibilityLabel("Clear \(command.title) shortcut")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct ShortcutBindingBadge: View {
    let shortcut: CueShotShortcut

    var body: some View {
        Text(shortcut.displayText)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(shortcut.isAssigned ? Color.primary : Color.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(width: 82, height: 27)
            .background(.white.opacity(shortcut.isAssigned ? 0.09 : 0.05), in: Capsule())
            .accessibilityLabel(shortcut.accessibilityText)
    }
}

private struct ResizeModifierPicker: View {
    @Binding var selection: CaptureResizeModifier

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(CaptureResizeModifier.allCases) { modifier in
                Text(modifier.menuTitle)
                    .tag(modifier)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(width: 132)
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
