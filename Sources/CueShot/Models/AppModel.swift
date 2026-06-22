import AppKit
import Combine
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedMode: CaptureMode = .element {
        didSet {
            userDefaults.set(selectedMode.rawValue, forKey: PreferenceKey.selectedMode)
        }
    }
    @Published var selectedTheme: CueTheme = .optic {
        didSet {
            CueColor.use(selectedTheme)
            userDefaults.set(selectedTheme.rawValue, forKey: PreferenceKey.selectedTheme)
        }
    }
    @Published var captureState: CaptureState = .ready
    @Published var permissions: PermissionStatus = .mockGranted
    @Published var recentCaptures: [CaptureRecord] = []
    @Published var selectedCaptureID: CaptureRecord.ID?
    @Published var autoPasteToCodex = false {
        didSet {
            userDefaults.set(autoPasteToCodex, forKey: PreferenceKey.autoPasteToCodex)
        }
    }
    @Published var handoffStatusSummary = "No handoff run yet"
    @Published var appServerDiagnosticSummary = "No App Server diagnostic run yet"
    @Published var codexCLIPathOverride = "" {
        didSet {
            userDefaults.set(codexCLIPathOverride, forKey: PreferenceKey.codexCLIPathOverride)
        }
    }
    @Published var showCaptureButtonAtLaunch = false {
        didSet {
            userDefaults.set(showCaptureButtonAtLaunch, forKey: PreferenceKey.showCaptureButtonAtLaunch)
        }
    }
    @Published var fileNameTemplate = "CueShot-{app}-{mode}-{date}" {
        didSet {
            userDefaults.set(fileNameTemplate, forKey: PreferenceKey.fileNameTemplate)
        }
    }
    @Published var widthResizeModifier: CaptureResizeModifier = .shift {
        didSet {
            guard widthResizeModifier != oldValue else { return }
            if widthResizeModifier == heightResizeModifier {
                heightResizeModifier = oldValue
            }
            userDefaults.set(widthResizeModifier.rawValue, forKey: PreferenceKey.widthResizeModifier)
        }
    }
    @Published var heightResizeModifier: CaptureResizeModifier = .option {
        didSet {
            guard heightResizeModifier != oldValue else { return }
            if heightResizeModifier == widthResizeModifier {
                widthResizeModifier = oldValue
            }
            userDefaults.set(heightResizeModifier.rawValue, forKey: PreferenceKey.heightResizeModifier)
        }
    }
    @Published private(set) var commandShortcuts: [CueShotCommand: CueShotShortcut] = CueShotCommand.defaultShortcuts {
        didSet {
            persistCommandShortcuts()
        }
    }
    @Published var currentTarget: CaptureTarget?
    @Published var gestureMonitorRunning = false
    @Published var capturePuckVisible = false
    @Published var oneClickCaptureArmed = false
    @Published var showOnboarding = false
    @Published var hasCompletedOnboarding = false {
        didSet {
            userDefaults.set(hasCompletedOnboarding, forKey: PreferenceKey.hasCompletedOnboarding)
        }
    }
    @Published private(set) var launchAtLoginEnabled = false
    @Published var lastErrorMessage: String?

    private let userDefaults: UserDefaults
    private let permissionService = PermissionService()
    private let captureService = CaptureService()
    private let handoffService = CodexHandoffService()
    private let axHitTestService = AXHitTestService()
    private let historyStore = CaptureHistoryStore()
    private let diagnostics = DiagnosticsLogger()
    private let overlayController = OverlayWindowController()
    private let gestureMonitor = GlobalGestureMonitor()
    private let capturePuckController = CapturePuckController()
    private lazy var settingsWindowController = SettingsWindowController(model: self)
    private var lastHoverResolveAt: TimeInterval = 0
    private var lastHoverPoint: CGPoint?
    private var lastHoverTarget: CaptureTarget?
    private var precisionSelectionState: PrecisionSelectionState?
    private let hoverResolveInterval: TimeInterval = 0.050
    private let fastHoverResolveInterval: TimeInterval = 0.025
    private let fastHoverDistance: CGFloat = 24
    private let minimumAreaSize: CGFloat = 8

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let storedMode = userDefaults.string(forKey: PreferenceKey.selectedMode),
           let mode = CaptureMode(rawValue: storedMode) {
            selectedMode = mode
        }
        if let storedTheme = userDefaults.string(forKey: PreferenceKey.selectedTheme),
           let theme = CueTheme(rawValue: storedTheme) {
            selectedTheme = theme
        }
        CueColor.use(selectedTheme)
        migrateClipboardFirstDefaultsIfNeeded()
        if userDefaults.object(forKey: PreferenceKey.autoPasteToCodex) != nil {
            autoPasteToCodex = userDefaults.bool(forKey: PreferenceKey.autoPasteToCodex)
        }
        if let storedCodexCLIPath = userDefaults.string(forKey: PreferenceKey.codexCLIPathOverride) {
            codexCLIPathOverride = storedCodexCLIPath
        }
        if userDefaults.object(forKey: PreferenceKey.showCaptureButtonAtLaunch) != nil {
            showCaptureButtonAtLaunch = userDefaults.bool(forKey: PreferenceKey.showCaptureButtonAtLaunch)
        }
        if let storedTemplate = userDefaults.string(forKey: PreferenceKey.fileNameTemplate),
           !storedTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fileNameTemplate = storedTemplate
        }
        let storedWidthModifier = userDefaults.string(forKey: PreferenceKey.widthResizeModifier)
            .flatMap(CaptureResizeModifier.init(rawValue:))
        let storedHeightModifier = userDefaults.string(forKey: PreferenceKey.heightResizeModifier)
            .flatMap(CaptureResizeModifier.init(rawValue:))
        if let storedWidthModifier, let storedHeightModifier, storedWidthModifier != storedHeightModifier {
            widthResizeModifier = storedWidthModifier
            heightResizeModifier = storedHeightModifier
        } else {
            if let storedWidthModifier {
                widthResizeModifier = storedWidthModifier
            }
            if let storedHeightModifier, storedHeightModifier != widthResizeModifier {
                heightResizeModifier = storedHeightModifier
            }
        }
        commandShortcuts = Self.loadCommandShortcuts(from: userDefaults)
        hasCompletedOnboarding = userDefaults.bool(forKey: PreferenceKey.hasCompletedOnboarding)
        showOnboarding = !hasCompletedOnboarding
        recentCaptures = historyStore.load()
        selectedCaptureID = recentCaptures.first?.id
        refreshLaunchAtLoginStatus()
        gestureMonitor.onEvent = { [weak self] event in
            self?.handleGestureEvent(event)
        }
    }

    func shortcut(for command: CueShotCommand) -> CueShotShortcut {
        commandShortcuts[command] ?? command.defaultShortcut
    }

    func setShortcut(_ shortcut: CueShotShortcut, for command: CueShotCommand) {
        var updated = commandShortcuts
        updated[command] = shortcut

        if shortcut.isAssigned {
            for otherCommand in CueShotCommand.allCases where otherCommand != command {
                if (updated[otherCommand] ?? otherCommand.defaultShortcut) == shortcut {
                    updated[otherCommand] = .unassigned
                }
            }
        }

        commandShortcuts = updated
    }

    func updateShortcut(for command: CueShotCommand, _ update: (inout CueShotShortcut) -> Void) {
        var shortcut = self.shortcut(for: command)
        update(&shortcut)
        setShortcut(shortcut, for: command)
    }

    func resetShortcut(for command: CueShotCommand) {
        setShortcut(command.defaultShortcut, for: command)
    }

    func clearShortcut(for command: CueShotCommand) {
        setShortcut(.unassigned, for: command)
    }

    func resetAllShortcuts() {
        commandShortcuts = CueShotCommand.defaultShortcuts
    }

    private func migrateClipboardFirstDefaultsIfNeeded() {
        guard userDefaults.object(forKey: PreferenceKey.clipboardFirstMigrationVersion) == nil else {
            return
        }

        if userDefaults.bool(forKey: PreferenceKey.autoPasteToCodex) {
            userDefaults.set(false, forKey: PreferenceKey.autoPasteToCodex)
        }
        userDefaults.set(1, forKey: PreferenceKey.clipboardFirstMigrationVersion)
    }

    func performCommand(_ command: CueShotCommand) {
        switch command {
        case .showCaptureControl:
            showCapturePuck()
        case .toggleCaptureControl:
            toggleCapturePuck()
        case .armCapture:
            armCaptureFromFloatingControl()
        case .cancelCapture:
            stopGestureMonitor()
        case .copyLastPNG:
            copyLastCapture()
        case .selectElementMode:
            selectModeAndRevealControl(.element)
        case .selectSelectionMode:
            selectModeAndRevealControl(.selection)
        case .selectWindowMode:
            selectModeAndRevealControl(.window)
        case .selectAreaMode:
            selectModeAndRevealControl(.area)
        case .selectScreenMode:
            selectModeAndRevealControl(.screen)
        case .selectOCRMode:
            selectModeAndRevealControl(.ocr)
        case .openSettings:
            openSettings()
        case .showOnboarding:
            openOnboarding()
        }
    }

    var selectedCapture: CaptureRecord? {
        recentCaptures.first { $0.id == selectedCaptureID } ?? recentCaptures.first
    }

    var selectedCaptureImage: NSImage? {
        guard let selectedCapture, let data = historyStore.pngData(for: selectedCapture) else {
            return nil
        }

        return NSImage(data: data)
    }

    var selectedCaptureURL: URL? {
        guard let selectedCapture else { return nil }
        return historyStore.pngURL(for: selectedCapture)
    }

    var destinationSummary: String {
        autoPasteToCodex ? "Copy PNG, then try experimental App Server" : "Copy PNG to Clipboard"
    }

    var destinationFallbackSummary: String {
        autoPasteToCodex ? "Advanced: CueShot still copies the PNG first, then tries Codex App Server. The visible Codex composer may still need Cmd+V or drag/drop." : "Every capture copies a clean PNG and file URL. Press Cmd+V in Codex, drag the preview, or reveal the PNG."
    }

    var permissionDiagnosticSummary: String {
        let bundleID = Bundle.main.bundleIdentifier ?? "unknown bundle id"
        let bundlePath = Bundle.main.bundleURL.path
        let codex = handoffService.runningCodexDescription() ?? "Codex is not currently running"
        let cli = CodexAppServerClient.resolveCLIPath(override: codexCLIPathOverride).displayDescription
        return "CueShot: \(bundleID) at \(bundlePath) · AX: \(permissions.accessibilityGranted ? "granted" : "missing") · Screen: \(permissions.screenRecordingGranted ? "granted" : "missing") · Codex app: \(codex) · Codex CLI: \(cli)"
    }

    var codexCLIResolutionSummary: String {
        CodexAppServerClient.resolveCLIPath(override: codexCLIPathOverride).displayDescription
    }

    var resizeBindings: CaptureResizeBindings {
        CaptureResizeBindings(widthModifier: widthResizeModifier, heightModifier: heightResizeModifier)
    }

    var resizeBindingSummary: String {
        "\(widthResizeModifier.title) changes width. \(heightResizeModifier.title) changes height."
    }

    var captureControlPresentation: CaptureControlPresentation {
        switch captureState {
        case .permissionNeeded(let kind):
            return .permission(kind)
        case .armed, .selectingArea, .capturing:
            return .armed
        case .copied, .pasteAttempted, .codexAppServerAccepted, .codexNotFocused:
            if let selectedCapture {
                return .captured(selectedCapture)
            }
            return .idle
        case .failed(let reason):
            return .failed(reason)
        case .ready:
            return .idle
        }
    }

    var lastCaptureSummary: String {
        guard let selectedCapture else {
            return "No PNG captured yet"
        }

        return "\(selectedCapture.displayHandoffStatus) - \(selectedCapture.fileSize)"
    }

    var historyLocationDescription: String {
        historyStore.historyDirectoryURL.path
    }

    var armActionTitle: String {
        selectedMode == .area ? "Arm Drag Capture" : "Arm Capture"
    }

    func selectMode(_ mode: CaptureMode) {
        let wasArmed = oneClickCaptureArmed
        if wasArmed {
            gestureMonitor.stop()
            gestureMonitorRunning = false
            oneClickCaptureArmed = false
            overlayController.hide()
            currentTarget = nil
            resetHoverCache()
            resetTargetAdjustment()
        }

        withAnimation(MotionSpec.navigationSpring) {
            selectedMode = mode
            captureState = .ready
        }

        if wasArmed {
            diagnostics.record("capture.mode changedWhileArmed mode=\(mode.rawValue)")
        }
    }

    func cycleTheme() {
        let themes = CueTheme.allCases
        guard let currentIndex = themes.firstIndex(of: selectedTheme) else {
            selectedTheme = .optic
            return
        }
        selectedTheme = themes[(currentIndex + 1) % themes.count]
    }

    func testCapture() {
        capture(at: currentTarget?.point ?? centerPointOfMainDisplay())
    }

    func copyLastCapture() {
        guard let capture = selectedCapture, let pngData = historyStore.pngData(for: capture) else {
            withAnimation(MotionSpec.quick) {
                captureState = .failed(reason: "No PNG to copy yet")
            }
            return
        }

        handoffService.copyToPasteboard(pngData: pngData, fileURL: historyStore.pngURL(for: capture))
        withAnimation(MotionSpec.quick) {
            captureState = .copied(reason: "PNG copied. Press Cmd+V in Codex or drag the preview.")
        }
    }

    func copyCapture(_ capture: CaptureRecord) {
        guard let pngData = historyStore.pngData(for: capture) else {
            captureState = .failed(reason: "Capture file missing")
            return
        }

        handoffService.copyToPasteboard(pngData: pngData, fileURL: historyStore.pngURL(for: capture))
        withAnimation(MotionSpec.quick) {
            captureState = .copied(reason: "PNG copied. Press Cmd+V in Codex or drag the preview.")
        }
    }

    func copyOCRText(_ capture: CaptureRecord) {
        guard let text = capture.normalizedOCRText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            captureState = .failed(reason: "No OCR text found in this capture.")
            return
        }

        NSPasteboard.general.clearContents()
        let copied = NSPasteboard.general.setString(text, forType: .string)
        withAnimation(MotionSpec.quick) {
            captureState = copied ? .copied(reason: "OCR text copied. Paste with Cmd+V.") : .failed(reason: "Could not copy OCR text.")
        }
    }

    func copySelectedOCRText() {
        guard let capture = selectedCapture else {
            captureState = .failed(reason: "No capture selected.")
            return
        }

        copyOCRText(capture)
    }

    func saveSelectedCaptureAs() {
        guard let capture = selectedCapture, let pngURL = historyStore.pngURL(for: capture) else {
            captureState = .failed(reason: "No PNG to save yet")
            return
        }

        let panel = NSSavePanel()
        panel.title = "Save CueShot PNG"
        panel.nameFieldStringValue = suggestedFileName(for: capture)
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let destinationURL = panel.url else {
            return
        }

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: pngURL, to: destinationURL)
            captureState = .copied(reason: "PNG saved")
        } catch {
            lastErrorMessage = error.localizedDescription
            captureState = .failed(reason: "Could not save PNG")
        }
    }

    func revealCapture(_ capture: CaptureRecord) {
        guard let url = historyStore.pngURL(for: capture) else {
            captureState = .failed(reason: "Capture file missing")
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func revealHistoryFolder() {
        NSWorkspace.shared.open(historyStore.historyDirectoryURL)
    }

    func deleteCapture(_ capture: CaptureRecord) {
        historyStore.delete(capture)
        recentCaptures.removeAll { $0.id == capture.id }
        selectedCaptureID = recentCaptures.first?.id
    }

    func clearHistory() {
        historyStore.clear()
        recentCaptures.removeAll()
        selectedCaptureID = nil
        currentTarget = nil
        captureState = .ready
    }

    func openCodex() {
        let activated = handoffService.activateCodexApp()
        withAnimation(MotionSpec.quick) {
            captureState = activated ? .ready : .codexNotFocused
        }
    }

    func testCodexHandoff() {
        handoffStatusSummary = "Running App Server handoff test..."
        appServerDiagnosticSummary = "Starting Codex App Server..."
        lastErrorMessage = nil

        Task {
            let testImage = makeHandoffTestImage()
            guard let testURL = writeHandoffTestImage(testImage) else {
                let message = "Could not create a saved PNG for Codex App Server test."
                handoffStatusSummary = message
                appServerDiagnosticSummary = message
                captureState = .failed(reason: message)
                lastErrorMessage = message
                return
            }

            let report = await handoffService.handoff(
                pngData: testImage,
                autoPaste: true,
                fileURL: testURL,
                codexCLIPathOverride: codexCLIPathOverride
            )
            handoffStatusSummary = report.summary
            appServerDiagnosticSummary = report.appServerDiagnostics?.summary ?? "No App Server diagnostics were returned."
            diagnostics.record("handoff.test result=\(report.result) note=\(report.note)")

            withAnimation(MotionSpec.captureSpring) {
                captureState = captureState(after: report)
            }

            if report.result.isAppServerAccepted {
                lastErrorMessage = nil
            } else if report.result.didAttemptPaste {
                lastErrorMessage = "App Server test: paste attempted, but attachment receipt is not verified."
            } else {
                lastErrorMessage = "App Server test: \(report.note)"
            }
        }
    }

    private func makeHandoffTestImage() -> Data {
        let width = 560
        let height = 280

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return Data()
        }

        context.setFillColor(CGColor(red: 0.12, green: 0.12, blue: 0.15, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        context.setFillColor(CGColor(red: 0.23, green: 0.68, blue: 1.0, alpha: 1.0))
        context.fill(CGRect(x: 26, y: 200, width: width - 52, height: 56))

        context.setFillColor(CGColor(red: 0.16, green: 0.17, blue: 0.18, alpha: 1.0))
        context.fill(CGRect(x: 26, y: 28, width: width - 52, height: 128))

        context.setStrokeColor(CGColor(red: 0.35, green: 0.9, blue: 0.95, alpha: 0.9))
        context.setLineWidth(6)
        context.stroke(CGRect(x: 26, y: 28, width: width - 52, height: 128))

        guard let cgImage = context.makeImage() else { return Data() }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        return bitmap.representation(using: .png, properties: [:]) ?? Data()
    }

    private func writeHandoffTestImage(_ data: Data) -> URL? {
        guard !data.isEmpty else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CueShot-Handoff-Test-\(UUID().uuidString)")
            .appendingPathExtension("png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            diagnostics.record("handoff.test writeFailed error=\(error.localizedDescription)")
            return nil
        }
    }

    func openMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.title.contains("CueShot") }?.makeKeyAndOrderFront(nil)
    }

    func openSettings() {
        hideCapturePuck()
        settingsWindowController.show()
    }

    func openOnboarding() {
        hideCapturePuck()
        openMainWindow()
        showOnboardingAgain()
    }

    func completeOnboarding(startCapture: Bool = false) {
        hasCompletedOnboarding = true
        withAnimation(MotionSpec.captureSpring) {
            showOnboarding = false
        }

        if startCapture {
            showCapturePuck()
        }
    }

    func showOnboardingAgain() {
        hideCapturePuck()
        refreshPermissions()
        withAnimation(MotionSpec.captureSpring) {
            showOnboarding = true
        }
    }

    func refreshLaunchAtLoginStatus() {
        if #available(macOS 13.0, *) {
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
        } else {
            launchAtLoginEnabled = false
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else {
            launchAtLoginEnabled = false
            lastErrorMessage = "Launch at login requires macOS 13 or newer."
            return
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginEnabled = enabled
        } catch {
            refreshLaunchAtLoginStatus()
            lastErrorMessage = error.localizedDescription
        }
    }

    func activateCaptureFromMenuBar() {
        armCaptureFromFloatingControl()
    }

    func armCaptureFromFloatingControl() {
        parkMainWindowsForCapture()
        armOneClickCapture()
    }

    func showCapturePuck() {
        capturePuckVisible = true
        capturePuckController.show(model: self)
        diagnostics.record("capturePuck.show visible=true")
    }

    func hideCapturePuck() {
        cancelOneClickCapture()
        capturePuckVisible = false
        capturePuckController.hide()
        diagnostics.record("capturePuck.hide visible=false")
    }

    func toggleCapturePuck() {
        capturePuckVisible ? hideCapturePuck() : showCapturePuck()
    }

    func applyLaunchPreferences() {
        guard hasCompletedOnboarding, showCaptureButtonAtLaunch else { return }
        showCapturePuck()
    }

    func armOneClickCapture() {
        refreshPermissions()
        showCapturePuck()

        if !permissions.accessibilityGranted {
            permissionService.requestAccessibilityPrompt()
        }
        if !permissions.screenRecordingGranted {
            permissionService.requestScreenRecordingPrompt()
        }

        guard permissions.accessibilityGranted else {
            withAnimation(MotionSpec.quick) {
                captureState = .permissionNeeded(.accessibility)
            }
            lastErrorMessage = "CueShot needs Accessibility for the one-click capture button."
            diagnostics.record("capturePuck.arm blocked=accessibility")
            return
        }

        guard permissions.screenRecordingGranted else {
            withAnimation(MotionSpec.quick) {
                captureState = .permissionNeeded(.screenRecording)
            }
            lastErrorMessage = "CueShot needs Screen Recording before it can capture pixels."
            diagnostics.record("capturePuck.arm blocked=screenRecording")
            return
        }

        oneClickCaptureArmed = true
        lastErrorMessage = nil
        currentTarget = nil
        resetHoverCache()
        resetTargetAdjustment()
        withAnimation(MotionSpec.navigationSpring) {
            captureState = .armed
        }
        diagnostics.record("capturePuck.arm begin")

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            guard oneClickCaptureArmed else { return }
            let capturesAreaDrag = selectedMode == .area
            gestureMonitorRunning = gestureMonitor.start(
                capturesPlainClick: !capturesAreaDrag,
                capturesAreaDrag: capturesAreaDrag,
                excludedZones: capturePuckController.eventExclusionZones(),
                resizeBindings: resizeBindings
            )
            diagnostics.record("capturePuck.monitor running=\(gestureMonitorRunning)")
            if !gestureMonitorRunning {
                oneClickCaptureArmed = false
                captureState = .permissionNeeded(.accessibility)
                lastErrorMessage = "CueShot could not start the one-click capture listener. Reopen Accessibility permissions and try again."
            }
        }
    }

    func cancelOneClickCapture() {
        oneClickCaptureArmed = false
        gestureMonitor.stop()
        gestureMonitorRunning = false
        currentTarget = nil
        resetHoverCache()
        resetTargetAdjustment()
        overlayController.hide()
        withAnimation(MotionSpec.quick) {
            captureState = permissions.screenRecordingGranted ? .ready : .permissionNeeded(.screenRecording)
        }
        diagnostics.record("capturePuck.cancel")
    }

    func startGestureMonitor() {
        refreshPermissions()
        if !permissions.accessibilityGranted {
            permissionService.requestAccessibilityPrompt()
        }
        if !permissions.screenRecordingGranted {
            permissionService.requestScreenRecordingPrompt()
        }

        oneClickCaptureArmed = false
        gestureMonitorRunning = gestureMonitor.start()
        diagnostics.record("gestureMonitor.start running=\(gestureMonitorRunning) accessibility=\(permissions.accessibilityGranted) screen=\(permissions.screenRecordingGranted)")
        if !gestureMonitorRunning {
            captureState = .permissionNeeded(.accessibility)
            lastErrorMessage = "CueShot could not start the global listener. Grant Accessibility and reopen the app."
        }
    }

    func stopGestureMonitor() {
        oneClickCaptureArmed = false
        gestureMonitor.stop()
        gestureMonitorRunning = false
        currentTarget = nil
        resetHoverCache()
        resetTargetAdjustment()
        overlayController.hide()
        withAnimation(MotionSpec.quick) {
            captureState = permissions.screenRecordingGranted ? .ready : .permissionNeeded(.screenRecording)
        }
    }

    func refreshPermissions() {
        permissions = permissionService.currentStatus()
        if !permissions.screenRecordingGranted {
            captureState = .permissionNeeded(.screenRecording)
        } else if case .permissionNeeded = captureState {
            captureState = .ready
        }
    }

    func openPermissionSettings(_ kind: PermissionKind) {
        permissionService.openSettings(for: kind)
    }

    func dismissCaptureStatus() {
        currentTarget = nil
        resetHoverCache()
        resetTargetAdjustment()
        overlayController.hide()
        withAnimation(MotionSpec.quick) {
            captureState = permissions.screenRecordingGranted ? .ready : .permissionNeeded(.screenRecording)
        }
    }

    private func handleGestureEvent(_ event: GestureEvent) {
        refreshPermissions()
        if !event.isHighFrequencyMove {
            diagnostics.record("gestureEvent=\(event) accessibility=\(permissions.accessibilityGranted) screen=\(permissions.screenRecordingGranted)")
        }

        guard permissions.screenRecordingGranted else {
            overlayController.hide()
            return
        }

        switch event {
        case .armed(let point), .moved(let point):
            guard selectedMode != .area else {
                overlayController.hide()
                return
            }

            if oneClickCaptureArmed && capturePuckController.containsScreenPoint(point) {
                return
            }

            if let precisionSelectionState {
                let target = CaptureRectAdjuster.targetWithAdjustedRect(
                    precisionSelectionState.baseTarget,
                    centeredAt: precisionSelectionState.anchorPoint,
                    size: precisionSelectionState.adjustedSize
                )
                lastHoverTarget = target
                lastHoverPoint = point
                lastHoverResolveAt = ProcessInfo.processInfo.systemUptime
                currentTarget = target
                withAnimation(MotionSpec.navigationSpring) {
                    captureState = .armed
                }
                overlayController.update(target: target, state: captureState)
                return
            }

            guard shouldResolveHoverTarget(at: point) else {
                if let target = lastHoverTarget {
                    overlayController.update(target: target, state: captureState)
                }
                return
            }

            let target = timedTarget(at: point, reason: "hover")
            guard !shouldBlockOwnAppTarget(target) else {
                currentTarget = nil
                lastHoverTarget = nil
                overlayController.hide()
                return
            }

            lastHoverTarget = target
            lastHoverPoint = point
            lastHoverResolveAt = ProcessInfo.processInfo.systemUptime
            currentTarget = target
            withAnimation(MotionSpec.navigationSpring) {
                captureState = .armed
            }
            overlayController.update(target: target, state: captureState)
        case .resize(let point, let deltaX, let deltaY, let axis):
            guard selectedMode != .area, oneClickCaptureArmed else { return }
            guard !capturePuckController.containsScreenPoint(point) else { return }

            let baseTarget = currentTarget ?? lastHoverTarget ?? timedTarget(at: point, reason: "resize")
            guard !shouldBlockOwnAppTarget(baseTarget) else {
                currentTarget = nil
                lastHoverTarget = nil
                overlayController.hide()
                return
            }

            let lockedState = precisionSelectionState ?? PrecisionSelectionState(
                baseTarget: baseTarget,
                anchorPoint: baseTarget.point,
                adjustedSize: baseTarget.rect.size,
                activeAxis: axis
            )
            let adjustedSize = CaptureRectAdjuster.adjustedSize(
                from: lockedState.adjustedSize,
                deltaX: deltaX,
                deltaY: deltaY,
                axis: axis,
                screenFrame: lockedState.baseTarget.screenFrame
            )
            let nextPrecisionState = lockedState.updating(size: adjustedSize, axis: axis)
            let target = CaptureRectAdjuster.targetWithAdjustedRect(
                nextPrecisionState.baseTarget,
                centeredAt: nextPrecisionState.anchorPoint,
                size: nextPrecisionState.adjustedSize
            )
            precisionSelectionState = nextPrecisionState
            lastHoverTarget = target
            lastHoverPoint = point
            lastHoverResolveAt = ProcessInfo.processInfo.systemUptime
            currentTarget = target
            withAnimation(MotionSpec.navigationSpring) {
                captureState = .armed
            }
            overlayController.update(target: target, state: captureState)
        case .areaStarted(let start, let current):
            guard selectedMode == .area else { return }
            let target = axHitTestService.areaTarget(from: start, to: current)
            currentTarget = target
            withAnimation(MotionSpec.navigationSpring) {
                captureState = .selectingArea
            }
            overlayController.update(target: target, state: captureState)
        case .areaChanged(let start, let current):
            guard selectedMode == .area else { return }
            let target = axHitTestService.areaTarget(from: start, to: current)
            currentTarget = target
            overlayController.update(target: target, state: .selectingArea)
        case .areaFinished(let start, let end):
            guard selectedMode == .area else { return }
            oneClickCaptureArmed = false
            gestureMonitor.stop()
            gestureMonitorRunning = false
            resetHoverCache()
            resetTargetAdjustment()

            let target = axHitTestService.areaTarget(from: start, to: end)
            guard target.rect.width >= minimumAreaSize, target.rect.height >= minimumAreaSize else {
                currentTarget = nil
                overlayController.hide()
                withAnimation(MotionSpec.quick) {
                    captureState = .failed(reason: "Area was too small. Drag a larger rectangle.")
                }
                diagnostics.record("capture.area cancelled=tooSmall")
                return
            }

            capture(target: target)
        case .cancelled:
            if oneClickCaptureArmed {
                gestureMonitor.stop()
                gestureMonitorRunning = false
                oneClickCaptureArmed = false
            }
            currentTarget = nil
            resetHoverCache()
            resetTargetAdjustment()
            withAnimation(MotionSpec.quick) {
                captureState = .ready
            }
            overlayController.hide()
        case .click(let point):
            guard !capturePuckController.containsScreenPoint(point) else {
                return
            }

            let preparedTarget = selectedMode == .area ? nil : currentTarget
            oneClickCaptureArmed = false
            gestureMonitor.stop()
            gestureMonitorRunning = false
            resetHoverCache()
            resetTargetAdjustment()
            if let preparedTarget, !shouldBlockOwnAppTarget(preparedTarget) {
                capture(target: preparedTarget)
            } else {
                capture(at: point)
            }
        case .tripleClick(let point):
            capture(at: point)
        }
    }

    private func capture(at point: CGPoint) {
        diagnostics.record("capture.begin point=\(Int(point.x)),\(Int(point.y)) mode=\(selectedMode.rawValue)")
        guard permissions.screenRecordingGranted else {
            captureState = .permissionNeeded(.screenRecording)
            diagnostics.record("capture.blocked missingScreenRecording")
            return
        }

        guard selectedMode != .area else {
            currentTarget = nil
            overlayController.hide()
            withAnimation(MotionSpec.quick) {
                captureState = .failed(reason: "Drag an area to capture it.")
            }
            diagnostics.record("capture.blocked areaRequiresDrag")
            return
        }

        let target = timedTarget(at: point, reason: "click")
        guard !shouldBlockOwnAppTarget(target) else {
            diagnostics.record("capture.blocked ownAppTarget")
            currentTarget = nil
            overlayController.hide()
            showCapturePuck()
            withAnimation(MotionSpec.quick) {
                captureState = .failed(reason: "CueShot moved itself aside. Click the target again.")
            }
            return
        }

        capture(target: target)
    }

    private func capture(target: CaptureTarget) {
        diagnostics.record("capture.begin target=\(Int(target.rect.width))x\(Int(target.rect.height)) mode=\(selectedMode.rawValue)")
        diagnostics.record("capture.target rect=\(Int(target.rect.width))x\(Int(target.rect.height)) app=\(target.sourceAppName) role=\(target.axRole) confidence=\(target.confidence.rawValue)")
        currentTarget = target
        let shouldRestoreCapturePuck = capturePuckVisible

        withAnimation(MotionSpec.captureSpring) {
            captureState = .capturing
        }
        capturePuckController.hide()
        overlayController.hide()

        Task { @MainActor in
            do {
                let result = try await captureService.capture(target: target, mode: selectedMode)
                let persistedRecord = try historyStore.persist(result: result)
                diagnostics.record("capture.persisted id=\(persistedRecord.id.uuidString) size=\(result.pngData.count)")

                let handoff = await handoffService.handoff(
                    pngData: result.pngData,
                    autoPaste: autoPasteToCodex,
                    fileURL: historyStore.pngURL(for: persistedRecord),
                    codexCLIPathOverride: codexCLIPathOverride
                )
                let finalRecord = persistedRecord.withHandoffStatus(handoff.result.historyStatus)
                try? historyStore.update(finalRecord)
                insertCapture(finalRecord)
                handoffStatusSummary = handoff.summary
                if let appServerDiagnostics = handoff.appServerDiagnostics {
                    appServerDiagnosticSummary = appServerDiagnostics.summary
                }
                diagnostics.record("capture.handoff result=\(handoff.result) note=\(handoff.note) codex=\(handoff.codexDescription ?? "none")")
                withAnimation(MotionSpec.captureSpring) {
                    captureState = captureState(after: handoff)
                }

                if handoff.result.isAppServerAccepted {
                    lastErrorMessage = nil
                } else if handoff.result.didAttemptPaste {
                    lastErrorMessage = autoPasteToCodex ? "App Server handoff: paste attempted, but attachment receipt is not verified." : nil
                } else if autoPasteToCodex {
                    lastErrorMessage = "App Server handoff: \(handoff.note)"
                } else {
                    lastErrorMessage = nil
                }

                try? await Task.sleep(for: .milliseconds(680))
                if case .pasteAttempted = captureState {
                    overlayController.hide()
                } else if case .codexAppServerAccepted = captureState {
                    overlayController.hide()
                } else if case .copied = captureState {
                    overlayController.hide()
                } else if case .failed = captureState {
                    overlayController.hide()
                }

                if shouldRestoreCapturePuck {
                    showCapturePuck()
                }
            } catch {
                lastErrorMessage = error.localizedDescription
                diagnostics.record("capture.failed error=\(error.localizedDescription)")
                withAnimation(MotionSpec.quick) {
                    captureState = .failed(reason: error.localizedDescription)
                }
                try? await Task.sleep(for: .milliseconds(900))
                overlayController.hide()

                if shouldRestoreCapturePuck {
                    showCapturePuck()
                }
            }
        }
    }

    private func insertCapture(_ capture: CaptureRecord) {
        recentCaptures.removeAll { $0.id == capture.id }
        recentCaptures.insert(capture, at: 0)
        recentCaptures = Array(recentCaptures.prefix(30))
        selectedCaptureID = capture.id
    }

    private func captureState(after report: HandoffReport) -> CaptureState {
        switch report.result {
        case .codexAppServerAccepted:
            return .codexAppServerAccepted
        case .codexAppServerUnavailable, .codexAppServerFailed:
            return .copied(reason: report.note)
        case .copiedOnly:
            return .copied(reason: "PNG copied. Press Cmd+V in Codex or drag the preview.")
        case .pasteAttempted, .sentVerified:
            return .pasteAttempted
        case .clipboardWriteFailed,
             .codexUnavailable,
             .codexFocusFailed,
             .codexPasteTargetUnavailable,
             .pasteEventBlocked:
            return .failed(reason: report.note)
        }
    }

    private func centerPointOfMainDisplay() -> CGPoint {
        let frame = CGDisplayBounds(CGMainDisplayID())
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    private func parkMainWindowsForCapture() {
        for window in NSApp.windows where !(window is NSPanel) {
            window.orderOut(nil)
        }
    }

    private func isCueShotTarget(_ target: CaptureTarget) -> Bool {
        target.sourceBundleID == Bundle.main.bundleIdentifier
            || target.sourceBundleID == "com.edgariraheta.CueShot"
    }

    private func shouldBlockOwnAppTarget(_ target: CaptureTarget) -> Bool {
        selectedMode != .selection && selectedMode != .ocr && isCueShotTarget(target)
    }

    private func shouldResolveHoverTarget(at point: CGPoint) -> Bool {
        let now = ProcessInfo.processInfo.systemUptime
        guard lastHoverResolveAt > 0, let lastHoverPoint else {
            return true
        }

        let elapsed = now - lastHoverResolveAt
        let distance = hypot(point.x - lastHoverPoint.x, point.y - lastHoverPoint.y)
        return elapsed >= hoverResolveInterval || (elapsed >= fastHoverResolveInterval && distance >= fastHoverDistance)
    }

    private func timedTarget(at point: CGPoint, reason: String) -> CaptureTarget {
        let start = ProcessInfo.processInfo.systemUptime
        let target = axHitTestService.target(at: point, mode: selectedMode)
        let milliseconds = Int(((ProcessInfo.processInfo.systemUptime - start) * 1000).rounded())

        if reason == "click" || milliseconds >= 12 {
            diagnostics.record("selector.\(reason) targetMs=\(milliseconds) app=\(target.sourceAppName) role=\(target.axRole) rect=\(Int(target.rect.width))x\(Int(target.rect.height))")
        }

        return target
    }

    private func resetHoverCache() {
        lastHoverResolveAt = 0
        lastHoverPoint = nil
        lastHoverTarget = nil
    }

    private func resetTargetAdjustment() {
        precisionSelectionState = nil
    }

    private func selectModeAndRevealControl(_ mode: CaptureMode) {
        selectMode(mode)
        showCapturePuck()
    }

    private static func loadCommandShortcuts(from userDefaults: UserDefaults) -> [CueShotCommand: CueShotShortcut] {
        var shortcuts = CueShotCommand.defaultShortcuts
        guard let data = userDefaults.data(forKey: PreferenceKey.commandShortcuts),
              let decoded = try? JSONDecoder().decode([String: CueShotShortcut].self, from: data)
        else {
            return shortcuts
        }

        for (rawCommand, shortcut) in decoded {
            guard let command = CueShotCommand(rawValue: rawCommand) else { continue }
            shortcuts[command] = shortcut
        }
        return shortcuts
    }

    private func persistCommandShortcuts() {
        let encodedShortcuts = Dictionary(uniqueKeysWithValues: commandShortcuts.map { command, shortcut in
            (command.rawValue, shortcut)
        })
        guard let data = try? JSONEncoder().encode(encodedShortcuts) else { return }
        userDefaults.set(data, forKey: PreferenceKey.commandShortcuts)
    }

    private func suggestedFileName(for capture: CaptureRecord) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let date = formatter.string(from: capture.createdAt)
        let values = [
            "{app}": capture.sourceAppName,
            "{mode}": capture.mode.rawValue,
            "{date}": date,
            "{size}": capture.dimensions.replacingOccurrences(of: " ", with: "")
        ]

        var name = fileNameTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            name = "CueShot-{app}-{mode}-{date}"
        }

        for (token, value) in values {
            name = name.replacingOccurrences(of: token, with: value)
        }

        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let sanitized = name
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .replacingOccurrences(of: "--", with: "-")
        return sanitized.hasSuffix(".png") ? sanitized : "\(sanitized).png"
    }
}

private enum PreferenceKey {
    static let selectedMode = "selectedMode"
    static let selectedTheme = "selectedTheme"
    static let autoPasteToCodex = "autoPasteToCodex"
    static let codexCLIPathOverride = "codexCLIPathOverride"
    static let showCaptureButtonAtLaunch = "showCaptureButtonAtLaunch"
    static let fileNameTemplate = "fileNameTemplate"
    static let widthResizeModifier = "widthResizeModifier"
    static let heightResizeModifier = "heightResizeModifier"
    static let commandShortcuts = "commandShortcuts"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
    static let clipboardFirstMigrationVersion = "clipboardFirstMigrationVersion"
}

private extension GestureEvent {
    var isHighFrequencyMove: Bool {
        if case .moved = self {
            return true
        }
        if case .areaChanged = self {
            return true
        }
        if case .resize = self {
            return true
        }
        return false
    }
}

enum CaptureMode: String, CaseIterable, Identifiable, Codable {
    case element
    case window
    case area
    case screen
    case selection
    case ocr

    var id: String { rawValue }

    var title: String {
        switch self {
        case .element: "Element"
        case .selection: "Selection"
        case .window: "Window"
        case .area: "Area"
        case .screen: "Screen"
        case .ocr: "OCR"
        }
    }

    var railTitle: String {
        switch self {
        case .element: "Element"
        case .selection: "Selection"
        case .window: "Window"
        case .area: "Area"
        case .screen: "Screen"
        case .ocr: "OCR"
        }
    }

    var methodTitle: String {
        switch self {
        case .element: "Exact"
        case .selection: "Estimated click"
        case .window: "Click window"
        case .area: "Drag region"
        case .screen: "Click display"
        case .ocr: "OCR capture"
        }
    }

    var helpText: String {
        switch self {
        case .element: "Exact Accessibility element capture when macOS exposes bounds."
        case .selection: "Estimated crop around the next click."
        case .window: "Containing window capture."
        case .area: "Manual drag rectangle capture."
        case .screen: "Current display capture."
        case .ocr: "Estimated region capture with OCR text extraction."
        }
    }

    var symbol: String {
        switch self {
        case .element: "scope"
        case .selection: "cursorarrow.rays"
        case .window: "macwindow"
        case .area: "selection.pin.in.out"
        case .screen: "display"
        case .ocr: "text.viewfinder"
        }
    }

    var idleInstruction: String {
        switch self {
        case .element: "Use the floating control, then click the exact UI element."
        case .selection: "Use the floating control, then click the region to estimate."
        case .window: "Use the floating control, then click inside the window."
        case .area: "Use the floating control, then drag the capture rectangle."
        case .screen: "Use the floating control, then click the display."
        case .ocr: "Use the floating control, then click to OCR the estimated region."
        }
    }

    var puckIdleTitle: String {
        switch self {
        case .element: "Element"
        case .selection: "Selection"
        case .window: "Window"
        case .area: "Area"
        case .screen: "Screen"
        case .ocr: "OCR"
        }
    }

    var puckPickerTitle: String {
        switch self {
        case .element: "Element"
        case .selection: "Select"
        case .window: "Window"
        case .area: "Area"
        case .screen: "Screen"
        case .ocr: "OCR"
        }
    }

    var puckIdleDetail: String {
        switch self {
        case .element: "Exact click capture"
        case .selection: "Estimated click crop"
        case .window: "Window click capture"
        case .area: "Drag region capture"
        case .screen: "Display click capture"
        case .ocr: "Estimated text capture"
        }
    }

    var puckArmedTitle: String {
        switch self {
        case .element: "Click exact element"
        case .selection: "Click estimated region"
        case .window: "Click window"
        case .area: "Drag capture area"
        case .screen: "Click display"
        case .ocr: "Click estimated region"
        }
    }

    var puckArmedDetail: String {
        switch self {
        case .area: "Drag, release, done. Esc cancels."
        default: "Scroll resizes. Click captures."
        }
    }
}

enum CaptureState: Equatable {
    case ready
    case armed
    case selectingArea
    case capturing
    case pasteAttempted
    case codexAppServerAccepted
    case copied(reason: String)
    case permissionNeeded(PermissionKind)
    case codexNotFocused
    case failed(reason: String)

    var label: String {
        switch self {
        case .ready: "Ready"
        case .armed: "Armed"
        case .selectingArea: "Selecting Area"
        case .capturing: "Capturing"
        case .pasteAttempted: "Paste Attempted"
        case .codexAppServerAccepted: "App Server Accepted"
        case .copied: "Copied"
        case .permissionNeeded(let kind): kind == .accessibility ? "Needs AX" : "Needs Screen"
        case .codexNotFocused: "Codex Not Focused"
        case .failed: "Failed"
        }
    }

    var detail: String {
        switch self {
        case .ready: "Use the floating control to arm the selected capture type."
        case .armed: "Scroll resizes. Modifier keys adjust one side."
        case .selectingArea: "Drag to draw the capture rectangle."
        case .capturing: "Freezing the target rectangle."
        case .pasteAttempted: "Legacy paste attempt. Verify Codex attached it."
        case .codexAppServerAccepted: "A new Codex App Server thread accepted the image. Drag the PNG into visible Codex if it does not appear."
        case .copied(let reason): reason
        case .permissionNeeded(let kind): kind.message
        case .codexNotFocused: "Capture copied. Focus Codex to paste."
        case .failed(let reason): reason
        }
    }

    var isActive: Bool {
        switch self {
        case .armed, .selectingArea, .capturing: true
        default: false
        }
    }
}

enum CaptureControlPresentation: Equatable {
    case idle
    case armed
    case captured(CaptureRecord)
    case permission(PermissionKind)
    case failed(String)
}

enum PermissionKind: Equatable {
    case accessibility
    case screenRecording

    var title: String {
        switch self {
        case .accessibility: "Accessibility"
        case .screenRecording: "Screen Recording"
        }
    }

    var message: String {
        switch self {
        case .accessibility: "CueShot needs Accessibility for the capture listener and exact element bounds."
        case .screenRecording: "CueShot needs Screen Recording to capture visible pixels."
        }
    }
}

struct PermissionStatus: Equatable {
    var accessibilityGranted: Bool
    var screenRecordingGranted: Bool

    static let mockGranted = PermissionStatus(accessibilityGranted: true, screenRecordingGranted: true)
}

enum HandoffResult: Equatable {
    case copiedOnly
    case clipboardWriteFailed
    case codexUnavailable
    case codexFocusFailed
    case codexPasteTargetUnavailable
    case codexAppServerUnavailable
    case codexAppServerFailed
    case codexAppServerAccepted
    case pasteEventBlocked
    case pasteAttempted
    case sentVerified
}

struct CaptureRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date
    let mode: CaptureMode
    let confidence: String
    let sourceAppName: String
    let axRole: String
    let dimensions: String
    let fileSize: String
    let handoffStatus: String
    let pngRelativePath: String?
    let recognizedText: String?

    init(
        id: UUID,
        createdAt: Date,
        mode: CaptureMode,
        confidence: String,
        sourceAppName: String,
        axRole: String,
        dimensions: String,
        fileSize: String,
        handoffStatus: String,
        pngRelativePath: String? = nil,
        recognizedText: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.mode = mode
        self.confidence = confidence
        self.sourceAppName = sourceAppName
        self.axRole = axRole
        self.dimensions = dimensions
        self.fileSize = fileSize
        self.handoffStatus = handoffStatus
        self.pngRelativePath = pngRelativePath
        self.recognizedText = recognizedText
    }

    var displayHandoffStatus: String {
        switch handoffStatus {
        case "Paste attempted", "Codex focus failed", "Copied":
            "Copied to Clipboard"
        default:
            handoffStatus
        }
    }

    var normalizedOCRText: String? {
        guard let text = recognizedText else {
            return nil
        }

        let normalized = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalized.isEmpty ? nil : normalized
    }

    static let samples: [CaptureRecord] = [
        CaptureRecord(id: UUID(), createdAt: .now.addingTimeInterval(-42), mode: .element, confidence: "Exact", sourceAppName: "Safari", axRole: "AXButton", dimensions: "286 x 144", fileSize: "418 KB", handoffStatus: "Copied", pngRelativePath: nil),
        CaptureRecord(id: UUID(), createdAt: .now.addingTimeInterval(-140), mode: .selection, confidence: "Estimated", sourceAppName: "Finder", axRole: "Estimated", dimensions: "260 x 160", fileSize: "362 KB", handoffStatus: "Copied", pngRelativePath: nil),
        CaptureRecord(id: UUID(), createdAt: .now.addingTimeInterval(-310), mode: .window, confidence: "Window", sourceAppName: "Codex", axRole: "NSWindow", dimensions: "760 x 480", fileSize: "1.2 MB", handoffStatus: "Copied", pngRelativePath: nil),
        CaptureRecord(id: UUID(), createdAt: .now.addingTimeInterval(-840), mode: .area, confidence: "Area", sourceAppName: "Xcode", axRole: "Selection", dimensions: "512 x 320", fileSize: "922 KB", handoffStatus: "Copied", pngRelativePath: nil)
    ]

    func withPNGRelativePath(_ path: String) -> CaptureRecord {
        CaptureRecord(
            id: id,
            createdAt: createdAt,
            mode: mode,
            confidence: confidence,
            sourceAppName: sourceAppName,
            axRole: axRole,
            dimensions: dimensions,
            fileSize: fileSize,
            handoffStatus: handoffStatus,
            pngRelativePath: path,
            recognizedText: recognizedText
        )
    }

    func withHandoffStatus(_ status: String) -> CaptureRecord {
        CaptureRecord(
            id: id,
            createdAt: createdAt,
            mode: mode,
            confidence: confidence,
            sourceAppName: sourceAppName,
            axRole: axRole,
            dimensions: dimensions,
            fileSize: fileSize,
            handoffStatus: status,
            pngRelativePath: pngRelativePath,
            recognizedText: recognizedText
        )
    }

    func withNormalizedOCRText(_ text: String?) -> CaptureRecord {
        CaptureRecord(
            id: id,
            createdAt: createdAt,
            mode: mode,
            confidence: confidence,
            sourceAppName: sourceAppName,
            axRole: axRole,
            dimensions: dimensions,
            fileSize: fileSize,
            handoffStatus: handoffStatus,
            pngRelativePath: pngRelativePath,
            recognizedText: text
        )
    }
}
