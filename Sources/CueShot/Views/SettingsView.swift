import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var confirmClearHistory = false
    @State private var shortcutSearch = ""
    @AppStorage("appearancePreference") private var appearancePreference: AppAppearancePreference = .system
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
        TabView {
            generalPane
                .tabItem { Label("General", systemImage: "gearshape") }

            capturePane
                .tabItem { Label("Capture", systemImage: "scope") }

            filesPane
                .tabItem { Label("Files & History", systemImage: "folder") }

            shortcutsPane
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }

            privacyPane
                .tabItem { Label("Privacy", systemImage: "lock.shield") }
        }
        .frame(width: 760, height: 650)
        .onAppear {
            focusedField = nil
            appearancePreference.apply()
            model.refreshPermissions()
            model.refreshLaunchAtLoginStatus()
        }
        .onChange(of: appearancePreference) { _, value in
            value.apply()
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

    private var generalPane: some View {
        SettingsPane(title: "General", subtitle: "Keep CueShot available where you expect it.") {
            Form {
                Section("Appearance") {
                    Picker("Appearance", selection: $appearancePreference) {
                        ForEach(AppAppearancePreference.allCases) { preference in
                            Text(preference.title).tag(preference)
                        }
                    }
                    Picker("Accent", selection: $model.selectedTheme) {
                        ForEach(CueTheme.allCases) { theme in
                            Text(theme.title).tag(theme)
                        }
                    }
                    Text(model.selectedTheme.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("App") {
                    Toggle("Launch CueShot at login", isOn: Binding(
                        get: { model.launchAtLoginEnabled },
                        set: { model.setLaunchAtLogin($0) }
                    ))
                    Toggle("Show Capture Control when CueShot opens", isOn: $model.showCaptureButtonAtLaunch)
                    Toggle("Hide Dock icon when menu bar item is active", isOn: $model.hideDockIconWhenMenuBarActive)
                    Text("CueShot stays available from the menu bar. Hide the Dock icon only if you are comfortable using it as a menu-bar utility.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
    }

    private var capturePane: some View {
        SettingsPane(title: "Capture", subtitle: "Choose the default mode and precision controls.") {
            Form {
                Section("Default mode") {
                    Picker("Default capture mode", selection: $model.selectedMode) {
                        ForEach(CaptureMode.allCases) { mode in
                            Label(mode.userFacingTitle, systemImage: mode.symbol).tag(mode)
                        }
                    }
                    Text(model.selectedMode.userFacingHelpText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Floating control") {
                    Toggle("Show Capture Control when CueShot opens", isOn: $model.showCaptureButtonAtLaunch)
                    Button {
                        model.showCapturePuck()
                    } label: {
                        Label("Show Capture Control", systemImage: "scope")
                    }
                }

                Section("Precision Controls") {
                    Picker("Width resize key", selection: $model.widthResizeModifier) {
                        ForEach(CaptureResizeModifier.allCases) { modifier in
                            Text(modifier.menuTitle).tag(modifier)
                        }
                    }
                    Picker("Height resize key", selection: $model.heightResizeModifier) {
                        ForEach(CaptureResizeModifier.allCases) { modifier in
                            Text(modifier.menuTitle).tag(modifier)
                        }
                    }
                    Text("Plain scroll resizes the whole target. Hold the selected modifier while scrolling to resize only width or height.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
        }
    }

    private var filesPane: some View {
        SettingsPane(title: "Files & History", subtitle: "Clipboard first, with local PNG history.") {
            Form {
                Section("Clipboard") {
                    SettingsValueRow(title: "Primary behavior", value: "Copy image to clipboard")
                    SettingsValueRow(title: "Format", value: "PNG")
                    Text("After capture, paste it anywhere, drag the preview, or reveal the local file in Finder.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("File names") {
                    TextField("CueShot-{app}-{mode}-{date}", text: $model.fileNameTemplate)
                        .focused($focusedField, equals: .fileNameTemplate)
                    Text("Tokens: {app}, {mode}, {date}, {size}")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("History") {
                    SettingsValueRow(title: "Kept locally", value: "Latest 30 captures")
                    SettingsValueRow(title: "Location", value: "~/Library/Application Support/CueShot/History")
                    HStack {
                        Button {
                            model.revealHistoryFolder()
                        } label: {
                            Label("Show History Folder", systemImage: "folder")
                        }

                        Button(role: .destructive) {
                            confirmClearHistory = true
                        } label: {
                            Label("Clear History", systemImage: "trash")
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
    }

    private var shortcutsPane: some View {
        SettingsPane(title: "Keyboard Shortcuts", subtitle: "Search commands and adjust keys without memorizing defaults.") {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    CommandCenterSearchField(text: $shortcutSearch)
                    Button {
                        model.resetAllShortcuts()
                    } label: {
                        Label("Reset All", systemImage: "arrow.counterclockwise")
                    }
                }

                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 8) {
                        ForEach(visibleShortcutCommands) { command in
                            CommandShortcutRow(model: model, command: command)
                        }

                        if visibleShortcutCommands.isEmpty {
                            ContentUnavailableView("No matching shortcuts", systemImage: "keyboard", description: Text("Try a different command, mode, or key name."))
                                .padding(.vertical, 28)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var privacyPane: some View {
        SettingsPane(title: "Permissions & Privacy", subtitle: "Required capture permissions stay clear. Codex handoff remains optional.") {
            Form {
                Section("Required for capture") {
                    PermissionSettingsRow(title: "Screen Recording", detail: "Required to capture visible screen content", granted: model.permissions.screenRecordingGranted) {
                        model.openPermissionSettings(.screenRecording)
                    }
                    PermissionSettingsRow(title: "Accessibility", detail: "Required to identify and select items under your cursor", granted: model.permissions.accessibilityGranted) {
                        model.openPermissionSettings(.accessibility)
                    }
                }

                Section("Codex Handoff, optional") {
                    Toggle("Try pasting into Codex after each capture", isOn: $model.autoPasteToCodex)
                    Text(CaptureCopy.visiblePasteHonesty)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    PermissionSettingsRow(title: "Automation", detail: model.permissions.automationStatus.detail, granted: model.permissions.automationGranted) {
                        model.openPermissionSettings(.automation)
                    }
                    Button {
                        model.testCodexHandoff()
                    } label: {
                        Label("Test Paste in Codex", systemImage: "arrow.clockwise.circle")
                    }
                    SettingsValueRow(title: "Last handoff", value: model.handoffStatusSummary)
                }

                Section("Troubleshooting") {
                    DisclosureGroup("Support Details") {
                        VStack(alignment: .leading, spacing: 10) {
                            SettingsDiagnosticBlock(title: "Permissions", value: model.permissionDiagnosticSummary)
                            SettingsDiagnosticBlock(title: "Paste Test Details", value: model.appServerDiagnosticSummary)
                        }
                    }
                    Button {
                        model.refreshPermissions()
                    } label: {
                        Label("Refresh Permissions", systemImage: "arrow.clockwise")
                    }
                    Button {
                        model.showOnboardingAgain()
                        model.openMainWindow()
                    } label: {
                        Label("Open Setup", systemImage: "questionmark.circle")
                    }
                }
            }
            .formStyle(.grouped)
        }
    }
}

private enum AppAppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    @MainActor
    func apply() {
        switch self {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }
}

private enum SettingsFocusField: Hashable {
    case fileNameTemplate
}

private struct SettingsPane<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.weight(.semibold))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            content()
        }
        .padding(22)
        .background(CueColor.canvas)
    }
}

private struct SettingsValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }
}

private struct SettingsDiagnosticBlock: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.callout.weight(.medium))
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(CueColor.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

private struct CommandCenterSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search shortcuts", text: $text)
                .textFieldStyle(.plain)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(CueColor.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(CueColor.separator.opacity(0.55), lineWidth: 1)
        }
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
            get: { CueShortcutModifierPreset.matching(shortcut.modifiers) },
            set: { preset in
                model.updateShortcut(for: command) { shortcut in
                    shortcut.modifiers = preset.modifiers
                }
            }
        )
    }

    private var keyBinding: Binding<CueShortcutKey?> {
        Binding(
            get: { shortcut.key },
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
                .foregroundStyle(CueColor.accent)
                .frame(width: 32, height: 32)
                .background(CueColor.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(command.title)
                    .font(.callout.weight(.semibold))
                Text(command.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            ShortcutBindingBadge(shortcut: shortcut)

            Picker("Modifiers", selection: modifierPresetBinding) {
                ForEach(CueShortcutModifierPreset.allCases) { preset in
                    Text(preset.title).tag(preset)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 92)

            Picker("Key", selection: keyBinding) {
                Text("Unassigned").tag(Optional<CueShortcutKey>.none)
                ForEach(CueShortcutKey.allCases) { key in
                    Text(key.displayTitle).tag(Optional(key))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 104)

            Button {
                model.resetShortcut(for: command)
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Reset to default")
            .accessibilityLabel("Reset \(command.title) shortcut")

            Button {
                model.clearShortcut(for: command)
            } label: {
                Image(systemName: "xmark.circle")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Clear shortcut")
            .accessibilityLabel("Clear \(command.title) shortcut")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(CueColor.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(CueColor.separator.opacity(0.45), lineWidth: 1)
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
            .frame(width: 82, height: 26)
            .background((shortcut.isAssigned ? CueColor.accent : Color.secondary).opacity(shortcut.isAssigned ? 0.12 : 0.08), in: Capsule())
            .accessibilityLabel(shortcut.accessibilityText)
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
                .foregroundStyle(granted ? CueColor.success : CueColor.warning)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if granted {
                Text("Allowed")
                    .foregroundStyle(CueColor.success)
            } else {
                Button("Open Settings") {
                    open()
                }
            }
        }
    }
}
