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
    @Published var captureState: CaptureState = .ready
    @Published var permissions: PermissionStatus = .mockGranted
    @Published var recentCaptures: [CaptureRecord] = []
    @Published var selectedCaptureID: CaptureRecord.ID?
    @Published var autoPasteToCodex = true {
        didSet {
            userDefaults.set(autoPasteToCodex, forKey: PreferenceKey.autoPasteToCodex)
        }
    }
    @Published var showCaptureButtonAtLaunch = true {
        didSet {
            userDefaults.set(showCaptureButtonAtLaunch, forKey: PreferenceKey.showCaptureButtonAtLaunch)
        }
    }
    @Published var fileNameTemplate = "CueShot-{app}-{mode}-{date}" {
        didSet {
            userDefaults.set(fileNameTemplate, forKey: PreferenceKey.fileNameTemplate)
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
    private var lastHoverResolveAt: TimeInterval = 0
    private var lastHoverPoint: CGPoint?
    private var lastHoverTarget: CaptureTarget?
    private let hoverResolveInterval: TimeInterval = 0.085
    private let fastHoverResolveInterval: TimeInterval = 0.045
    private let fastHoverDistance: CGFloat = 48
    private let minimumAreaSize: CGFloat = 8

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let storedMode = userDefaults.string(forKey: PreferenceKey.selectedMode),
           let mode = CaptureMode(rawValue: storedMode) {
            selectedMode = mode
        }
        if userDefaults.object(forKey: PreferenceKey.autoPasteToCodex) != nil {
            autoPasteToCodex = userDefaults.bool(forKey: PreferenceKey.autoPasteToCodex)
        }
        if userDefaults.object(forKey: PreferenceKey.showCaptureButtonAtLaunch) != nil {
            showCaptureButtonAtLaunch = userDefaults.bool(forKey: PreferenceKey.showCaptureButtonAtLaunch)
        }
        if let storedTemplate = userDefaults.string(forKey: PreferenceKey.fileNameTemplate),
           !storedTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fileNameTemplate = storedTemplate
        }
        hasCompletedOnboarding = userDefaults.bool(forKey: PreferenceKey.hasCompletedOnboarding)
        showOnboarding = !hasCompletedOnboarding
        recentCaptures = historyStore.load()
        selectedCaptureID = recentCaptures.first?.id
        refreshLaunchAtLoginStatus()
        gestureMonitor.onEvent = { [weak self] event in
            self?.handleGestureEvent(event)
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

    var destinationSummary: String {
        autoPasteToCodex ? "Send to Codex when available" : "Copy PNG only"
    }

    var destinationFallbackSummary: String {
        autoPasteToCodex ? "Fallback: copy PNG if Codex is unavailable." : "Every capture stays copied to your clipboard."
    }

    var lastCaptureSummary: String {
        guard let selectedCapture else {
            return "No PNG captured yet"
        }

        return "\(selectedCapture.handoffStatus) - \(selectedCapture.fileSize)"
    }

    var historyLocationDescription: String {
        historyStore.historyDirectoryURL.path
    }

    var armActionTitle: String {
        selectedMode == .area ? "Arm Drag Capture" : "Arm Capture"
    }

    func selectMode(_ mode: CaptureMode) {
        withAnimation(MotionSpec.navigationSpring) {
            selectedMode = mode
            captureState = oneClickCaptureArmed ? .armed : .ready
        }
    }

    func testCapture() {
        capture(at: currentTarget?.point ?? centerPointOfMainDisplay())
    }

    func copyLastCapture() {
        guard let capture = selectedCapture, let pngData = historyStore.pngData(for: capture) else {
            withAnimation(MotionSpec.quick) {
                captureState = .copyFallback(reason: "No PNG to copy yet")
            }
            return
        }

        handoffService.copyToPasteboard(pngData: pngData)
        withAnimation(MotionSpec.quick) {
            captureState = .copyFallback(reason: "Last PNG copied")
        }
    }

    func copyCapture(_ capture: CaptureRecord) {
        guard let pngData = historyStore.pngData(for: capture) else {
            captureState = .copyFallback(reason: "Capture file missing")
            return
        }

        handoffService.copyToPasteboard(pngData: pngData)
        withAnimation(MotionSpec.quick) {
            captureState = .copyFallback(reason: "PNG copied")
        }
    }

    func saveSelectedCaptureAs() {
        guard let capture = selectedCapture, let pngURL = historyStore.pngURL(for: capture) else {
            captureState = .copyFallback(reason: "No PNG to save yet")
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
            captureState = .copyFallback(reason: "PNG saved")
        } catch {
            lastErrorMessage = error.localizedDescription
            captureState = .copyFallback(reason: "Could not save PNG")
        }
    }

    func revealCapture(_ capture: CaptureRecord) {
        guard let url = historyStore.pngURL(for: capture) else {
            captureState = .copyFallback(reason: "Capture file missing")
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

    func openMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.title.contains("CueShot") }?.makeKeyAndOrderFront(nil)
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
    }

    func hideCapturePuck() {
        cancelOneClickCapture()
        capturePuckVisible = false
        capturePuckController.hide()
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
        withAnimation(MotionSpec.navigationSpring) {
            captureState = .armed
        }
        diagnostics.record("capturePuck.arm begin")

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            guard oneClickCaptureArmed else { return }
            let capturesAreaDrag = selectedMode == .area
            gestureMonitorRunning = gestureMonitor.start(capturesPlainClick: !capturesAreaDrag, capturesAreaDrag: capturesAreaDrag)
            diagnostics.record("capturePuck.monitor running=\(gestureMonitorRunning)")
            if !gestureMonitorRunning {
                oneClickCaptureArmed = false
                captureState = .permissionNeeded(.accessibility)
                lastErrorMessage = "CueShot could not start the one-click capture listener."
            }
        }
    }

    func cancelOneClickCapture() {
        oneClickCaptureArmed = false
        gestureMonitor.stop()
        gestureMonitorRunning = false
        currentTarget = nil
        resetHoverCache()
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

            let target = axHitTestService.areaTarget(from: start, to: end)
            guard target.rect.width >= minimumAreaSize, target.rect.height >= minimumAreaSize else {
                currentTarget = nil
                overlayController.hide()
                withAnimation(MotionSpec.quick) {
                    captureState = .copyFallback(reason: "Area was too small. Drag a larger rectangle.")
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
            withAnimation(MotionSpec.quick) {
                captureState = .ready
            }
            overlayController.hide()
        case .click(let point):
            guard !capturePuckController.containsScreenPoint(point) else {
                return
            }

            oneClickCaptureArmed = false
            gestureMonitor.stop()
            gestureMonitorRunning = false
            resetHoverCache()
            capture(at: point)
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
                captureState = .copyFallback(reason: "Drag an area to capture it.")
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
                captureState = .copyFallback(reason: "CueShot moved itself aside. Click the target again.")
            }
            return
        }

        capture(target: target)
    }

    private func capture(target: CaptureTarget) {
        diagnostics.record("capture.begin target=\(Int(target.rect.width))x\(Int(target.rect.height)) mode=\(selectedMode.rawValue)")
        diagnostics.record("capture.target rect=\(Int(target.rect.width))x\(Int(target.rect.height)) app=\(target.sourceAppName) role=\(target.axRole) confidence=\(target.confidence.rawValue)")
        currentTarget = target

        withAnimation(MotionSpec.captureSpring) {
            captureState = .capturing
        }
        overlayController.update(target: target, state: captureState)

        Task { @MainActor in
            do {
                let result = try await captureService.capture(target: target, mode: selectedMode)
                let persistedRecord = try historyStore.persist(result: result)
                diagnostics.record("capture.persisted id=\(persistedRecord.id.uuidString) size=\(result.pngData.count)")

                let handoff = handoffService.handoff(pngData: result.pngData, autoPaste: autoPasteToCodex)
                let finalRecord = persistedRecord.withHandoffStatus(handoff == .sent ? "Sent" : "Copied")
                try? historyStore.update(finalRecord)
                insertCapture(finalRecord)
                diagnostics.record("capture.handoff result=\(handoff)")
                withAnimation(MotionSpec.captureSpring) {
                    captureState = handoff == .sent ? .sentToCodex : .copyFallback(reason: "PNG copied - focus Codex and paste")
                }

                try? await Task.sleep(for: .milliseconds(680))
                if case .sentToCodex = captureState {
                    overlayController.hide()
                } else if case .copyFallback = captureState {
                    overlayController.hide()
                }
            } catch {
                lastErrorMessage = error.localizedDescription
                diagnostics.record("capture.failed error=\(error.localizedDescription)")
                withAnimation(MotionSpec.quick) {
                    captureState = .copyFallback(reason: error.localizedDescription)
                }
                try? await Task.sleep(for: .milliseconds(900))
                overlayController.hide()
            }
        }
    }

    private func insertCapture(_ capture: CaptureRecord) {
        recentCaptures.removeAll { $0.id == capture.id }
        recentCaptures.insert(capture, at: 0)
        recentCaptures = Array(recentCaptures.prefix(30))
        selectedCaptureID = capture.id
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
        selectedMode != .selection && isCueShotTarget(target)
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
    static let autoPasteToCodex = "autoPasteToCodex"
    static let showCaptureButtonAtLaunch = "showCaptureButtonAtLaunch"
    static let fileNameTemplate = "fileNameTemplate"
    static let hasCompletedOnboarding = "hasCompletedOnboarding"
}

private extension GestureEvent {
    var isHighFrequencyMove: Bool {
        if case .moved = self {
            return true
        }
        if case .areaChanged = self {
            return true
        }
        return false
    }
}

enum CaptureMode: String, CaseIterable, Identifiable, Codable {
    case element
    case selection
    case window
    case area
    case screen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .element: "Element"
        case .selection: "Selection"
        case .window: "Window"
        case .area: "Area"
        case .screen: "Screen"
        }
    }

    var railTitle: String {
        switch self {
        case .element: "Element"
        case .selection: "Selection"
        case .window: "Window"
        case .area: "Area"
        case .screen: "Screen"
        }
    }

    var methodTitle: String {
        switch self {
        case .element: "Exact"
        case .selection: "Estimated click"
        case .window: "Click window"
        case .area: "Drag region"
        case .screen: "Click display"
        }
    }

    var helpText: String {
        switch self {
        case .element: "Exact Accessibility element capture when macOS exposes bounds."
        case .selection: "Estimated crop around the next click."
        case .window: "Containing window capture."
        case .area: "Manual drag rectangle capture."
        case .screen: "Current display capture."
        }
    }

    var symbol: String {
        switch self {
        case .element: "scope"
        case .selection: "cursorarrow.rays"
        case .window: "macwindow"
        case .area: "selection.pin.in.out"
        case .screen: "display"
        }
    }

    var idleInstruction: String {
        switch self {
        case .element: "Use the floating control, then click the exact UI element."
        case .selection: "Use the floating control, then click the region to estimate."
        case .window: "Use the floating control, then click inside the window."
        case .area: "Use the floating control, then drag the capture rectangle."
        case .screen: "Use the floating control, then click the display."
        }
    }

    var puckIdleTitle: String {
        switch self {
        case .element: "Element"
        case .selection: "Selection"
        case .window: "Window"
        case .area: "Area"
        case .screen: "Screen"
        }
    }

    var puckIdleDetail: String {
        switch self {
        case .element: "Exact click to Codex"
        case .selection: "Estimated click to Codex"
        case .window: "Window click to Codex"
        case .area: "Drag region to Codex"
        case .screen: "Display click to Codex"
        }
    }

    var puckArmedTitle: String {
        switch self {
        case .element: "Click exact element"
        case .selection: "Click estimated region"
        case .window: "Click window"
        case .area: "Drag capture area"
        case .screen: "Click display"
        }
    }

    var puckArmedDetail: String {
        switch self {
        case .area: "Drag, release, done. Esc cancels."
        default: "One click captures. Esc cancels."
        }
    }
}

enum CaptureState: Equatable {
    case ready
    case armed
    case selectingArea
    case capturing
    case sentToCodex
    case permissionNeeded(PermissionKind)
    case codexNotFocused
    case copyFallback(reason: String)

    var label: String {
        switch self {
        case .ready: "Ready"
        case .armed: "Armed"
        case .selectingArea: "Selecting Area"
        case .capturing: "Capturing"
        case .sentToCodex: "Sent"
        case .permissionNeeded(let kind): kind == .accessibility ? "Needs AX" : "Needs Screen"
        case .codexNotFocused: "Codex Not Focused"
        case .copyFallback: "Fallback"
        }
    }

    var detail: String {
        switch self {
        case .ready: "Use the floating control to arm the selected capture type."
        case .armed: "Click or drag the target. Escape stops."
        case .selectingArea: "Drag to draw the capture rectangle."
        case .capturing: "Freezing the target rectangle."
        case .sentToCodex: "PNG prepared for Codex."
        case .permissionNeeded(let kind): kind.message
        case .codexNotFocused: "Capture copied. Focus Codex to paste."
        case .copyFallback(let reason): reason
        }
    }

    var isActive: Bool {
        switch self {
        case .armed, .selectingArea, .capturing: true
        default: false
        }
    }
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
        case .accessibility: "CueShot needs Accessibility to detect the element under your cursor."
        case .screenRecording: "CueShot needs Screen Recording to capture visible pixels."
        }
    }
}

struct PermissionStatus: Equatable {
    var accessibilityGranted: Bool
    var screenRecordingGranted: Bool

    static let mockGranted = PermissionStatus(accessibilityGranted: true, screenRecordingGranted: true)
}

enum HandoffResult {
    case sent
    case copied
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

    static let samples: [CaptureRecord] = [
        CaptureRecord(id: UUID(), createdAt: .now.addingTimeInterval(-42), mode: .element, confidence: "Exact", sourceAppName: "Safari", axRole: "AXButton", dimensions: "286 x 144", fileSize: "418 KB", handoffStatus: "Sent", pngRelativePath: nil),
        CaptureRecord(id: UUID(), createdAt: .now.addingTimeInterval(-140), mode: .selection, confidence: "Estimated", sourceAppName: "Finder", axRole: "Estimated", dimensions: "260 x 160", fileSize: "362 KB", handoffStatus: "Copied", pngRelativePath: nil),
        CaptureRecord(id: UUID(), createdAt: .now.addingTimeInterval(-310), mode: .window, confidence: "Window", sourceAppName: "Codex", axRole: "NSWindow", dimensions: "760 x 480", fileSize: "1.2 MB", handoffStatus: "Copied", pngRelativePath: nil),
        CaptureRecord(id: UUID(), createdAt: .now.addingTimeInterval(-840), mode: .area, confidence: "Area", sourceAppName: "Xcode", axRole: "Selection", dimensions: "512 x 320", fileSize: "922 KB", handoffStatus: "Sent", pngRelativePath: nil)
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
            pngRelativePath: path
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
            pngRelativePath: pngRelativePath
        )
    }
}
