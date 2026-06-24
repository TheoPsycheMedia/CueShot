import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var showingDetails = false

    var body: some View {
        Group {
            if model.showOnboarding {
                OnboardingView(model: model)
            } else {
                CaptureWorkspace(model: model, showingDetails: $showingDetails)
            }
        }
        .background(CuePremiumBackdrop())
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                CaptureModeMenu(model: model)

                Button {
                    model.armCaptureFromFloatingControl()
                } label: {
                    Label("Capture", systemImage: model.selectedMode.symbol)
                }
                .keyboardShortcut(.return, modifiers: [])
                .help(model.selectedMode.userFacingIdleInstruction)
                .accessibilityIdentifier("MainCaptureButton")

                Button {
                    model.toggleCapturePuck()
                } label: {
                    Label(model.capturePuckVisible ? "Hide Control" : "Show Control", systemImage: model.capturePuckVisible ? "eye.slash" : "scope")
                }
                .help(model.capturePuckVisible ? "Hide the floating capture control" : "Show the floating capture control")

                Button {
                    withAnimation(MotionSpec.stateChange) {
                        showingDetails.toggle()
                    }
                } label: {
                    Label("Details", systemImage: "sidebar.right")
                }
                .help(showingDetails ? "Hide capture details" : "Show capture details")
            }

            ToolbarItemGroup(placement: .automatic) {
                Button {
                    model.openOnboarding()
                } label: {
                    Label("Setup", systemImage: "questionmark.circle")
                }
                .help("Open setup")

                Button {
                    model.openSettings()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Open settings")
            }
        }
        .inspector(isPresented: $showingDetails) {
            InspectorView(model: model)
                .frame(minWidth: 260, idealWidth: 300)
        }
        .onAppear {
            model.applyLaunchPreferences()
        }
    }
}

private struct CaptureWorkspace: View {
    @ObservedObject var model: AppModel
    @Binding var showingDetails: Bool

    var body: some View {
        VStack(spacing: 0) {
            WorkspaceStatusLine(model: model)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(.regularMaterial)

            Divider()

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    CaptureLensView(model: model)
                        .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)

                    CueWidgetRail(model: model, showingDetails: $showingDetails)
                        .frame(width: 258)
                }

                VStack(spacing: 14) {
                    CaptureLensView(model: model)
                    CueWidgetRail(model: model, showingDetails: $showingDetails)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !model.recentCaptures.isEmpty {
                Divider()
                RecentCaptureStrip(model: model)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(.regularMaterial)
            }
        }
    }
}

private struct WorkspaceStatusLine: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 14) {
            CueBrandLockup(active: model.captureState.isActive)

            Divider()
                .frame(height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(model.captureState.userFacingLabel)
                    .font(.callout.weight(.semibold))
                Text(statusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .cueLiquidBrandGlass(cornerRadius: 12)

            Spacer(minLength: 12)

            if case .permissionNeeded(let kind) = model.captureState {
                Button(kind.presentation.actionTitle) {
                    model.openPermissionSettings(kind)
                }
                .buttonStyle(.borderedProminent)
            } else if case .failed = model.captureState {
                Button("Try Again") {
                    model.armCaptureFromFloatingControl()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var statusDetail: String {
        if model.captureState.isActive {
            return model.selectedMode.userFacingArmedInstruction
        }
        if model.selectedCapture != nil {
            return "Paste it anywhere, drag the preview, or save a copy."
        }
        return model.selectedMode.userFacingIdleInstruction
    }
}

private struct CueWidgetRail: View {
    @ObservedObject var model: AppModel
    @Binding var showingDetails: Bool

    var body: some View {
        VStack(spacing: 10) {
            ThemeWidget(model: model)
            OutputWidget(model: model)
            PermissionWidget(model: model)
            LastCaptureWidget(model: model, showingDetails: $showingDetails)
            HandoffWidget(model: model)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

private struct ThemeWidget: View {
    @ObservedObject var model: AppModel

    var body: some View {
        CueWidgetCard(title: model.selectedTheme.title, subtitle: model.selectedTheme.detail, systemImage: "paintpalette", vivid: true) {
            HStack(spacing: 8) {
                ThemeDot(color: CueColor.accent)
                ThemeDot(color: CueColor.secondaryAccent)
                ThemeDot(color: CueColor.glow)
                Spacer()
                Button("Change") {
                    model.cycleTheme()
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

private struct OutputWidget: View {
    @ObservedObject var model: AppModel

    var body: some View {
        CueWidgetCard(title: "Clipboard first", subtitle: "PNG is ready to paste or drag.", systemImage: "doc.on.clipboard") {
            HStack(spacing: 8) {
                Button("Copy Again") {
                    model.copyLastCapture()
                }
                .disabled(model.selectedCapture == nil)

                Button("Finder") {
                    if let capture = model.selectedCapture {
                        model.revealCapture(capture)
                    }
                }
                .disabled(model.selectedCapture == nil)
            }
            .buttonStyle(.borderless)
        }
    }
}

private struct PermissionWidget: View {
    @ObservedObject var model: AppModel

    var body: some View {
        CueWidgetCard(title: "Permissions", subtitle: permissionSubtitle, systemImage: "lock.shield") {
            VStack(alignment: .leading, spacing: 7) {
                MiniPermissionPill(title: "Screen", granted: model.permissions.screenRecordingGranted) {
                    model.openPermissionSettings(.screenRecording)
                }
                MiniPermissionPill(title: "Access", granted: model.permissions.accessibilityGranted) {
                    model.openPermissionSettings(.accessibility)
                }
            }
        }
    }

    private var permissionSubtitle: String {
        model.permissions.capturePermissionsGranted ? "Ready for capture." : "Required setup is missing."
    }
}

private struct LastCaptureWidget: View {
    @ObservedObject var model: AppModel
    @Binding var showingDetails: Bool

    var body: some View {
        CueWidgetCard(title: "Last capture", subtitle: subtitle, systemImage: model.selectedCapture?.mode.symbol ?? "clock") {
            if let capture = model.selectedCapture {
                VStack(alignment: .leading, spacing: 7) {
                    Text(capture.sourceAppName)
                        .font(.caption.weight(.semibold))
                    Text(capture.detailsSummary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Button("Details") {
                        showingDetails = true
                    }
                    .buttonStyle(.borderless)
                }
            } else {
                Text("Recent captures will appear here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var subtitle: String {
        guard let capture = model.selectedCapture else { return "No captures yet." }
        return capture.displayHandoffStatus
    }
}

private struct HandoffWidget: View {
    @ObservedObject var model: AppModel

    var body: some View {
        CueWidgetCard(title: "Codex", subtitle: model.autoPasteToCodex ? "Paste command is optional." : "Manual paste or drag.", systemImage: "keyboard") {
            Toggle("Try Paste", isOn: $model.autoPasteToCodex)
                .toggleStyle(.switch)
                .font(.caption)
            Text("CueShot copies first. Confirm Codex attached the image before sending.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct CueWidgetCard<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var vivid = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CueColor.accent)
                    .frame(width: 28, height: 28)
                    .background(CueColor.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cueThemeWidget(cornerRadius: 16, vivid: vivid)
    }
}

private struct ThemeDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 13, height: 13)
            .overlay { Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 1) }
    }
}

private struct MiniPermissionPill: View {
    let title: String
    let granted: Bool
    let open: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(granted ? CueColor.success : CueColor.warning)
            Text(title)
            Spacer()
            if !granted {
                Button("Open", action: open)
                    .buttonStyle(.borderless)
            } else {
                Text("Allowed")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }
}

struct CaptureModeMenu: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Menu {
            ForEach(CaptureMode.allCases) { mode in
                Button {
                    model.selectMode(mode)
                } label: {
                    Label(mode.userFacingTitle, systemImage: mode.symbol)
                }
            }
        } label: {
            Label(model.selectedMode.userFacingTitle, systemImage: model.selectedMode.symbol)
        }
        .help("Choose capture mode")
    }
}

private struct RecentCaptureStrip: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(model.recentCaptures.prefix(12)) { capture in
                    RecentCaptureChip(
                        capture: capture,
                        selected: capture.id == model.selectedCaptureID,
                        select: {
                            withAnimation(MotionSpec.historyInsertion) {
                                model.selectedCaptureID = capture.id
                            }
                        }
                    )
                }
            }
        }
        .accessibilityLabel("Recent captures")
    }
}

private struct RecentCaptureChip: View {
    let capture: CaptureRecord
    let selected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 8) {
                Image(systemName: capture.mode.symbol)
                    .foregroundStyle(selected ? CueColor.accent : .secondary)
                    .frame(width: 24, height: 24)
                    .background((selected ? CueColor.accent : Color.secondary).opacity(0.10), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

                VStack(alignment: .leading, spacing: 1) {
                    Text(capture.sourceAppName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(capture.detailsSummary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: selected ? CueColor.vividWidgetGradientColors : CueColor.widgetGradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(selected ? CueColor.accent.opacity(0.35) : CueColor.separator.opacity(0.45), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(capture.mode.userFacingTitle) capture from \(capture.sourceAppName), \(capture.dimensions)")
    }
}
