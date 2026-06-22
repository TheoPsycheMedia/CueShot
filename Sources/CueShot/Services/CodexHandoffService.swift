import AppKit
import ApplicationServices
import Foundation

struct HandoffReport: Equatable {
    let result: HandoffResult
    let codexFound: Bool
    let codexFocused: Bool
    let pasteShortcutPosted: Bool
    let bytesInPasteboard: Int
    let codexDescription: String?
    let note: String
    let appServerDiagnostics: CodexAppServerClient.AppServerDiagnostics?

    init(
        result: HandoffResult,
        codexFound: Bool,
        codexFocused: Bool,
        pasteShortcutPosted: Bool,
        bytesInPasteboard: Int,
        codexDescription: String?,
        note: String,
        appServerDiagnostics: CodexAppServerClient.AppServerDiagnostics? = nil
    ) {
        self.result = result
        self.codexFound = codexFound
        self.codexFocused = codexFocused
        self.pasteShortcutPosted = pasteShortcutPosted
        self.bytesInPasteboard = bytesInPasteboard
        self.codexDescription = codexDescription
        self.note = note
        self.appServerDiagnostics = appServerDiagnostics
    }

    var summary: String {
        if let codexDescription {
            return "\(result.displayTitle) · \(note) · \(codexDescription)"
        }
        return "\(result.displayTitle) · \(note)"
    }
}

struct CodexApplicationMatcher {
    static func isCodexDesktopTarget(
        localizedName: String?,
        bundleIdentifier: String?,
        bundleLastPathComponent: String?
    ) -> Bool {
        if bundleIdentifier?.lowercased() == "com.openai.codex" {
            return true
        }

        if bundleLastPathComponent == "Codex.app" {
            return true
        }

        return localizedName == "Codex"
    }
}

struct CodexComposerCandidate: Equatable {
    var role: String? = nil
    var subrole: String? = nil
    var roleDescription: String? = nil
    var title: String? = nil
    var description: String? = nil
    var placeholder: String? = nil
    var enabled: Bool? = nil

    var score: Int {
        guard isEditableRole else {
            return 0
        }

        var value = 0
        switch role {
        case kAXTextAreaRole:
            value += 70
        case kAXTextFieldRole:
            value += 55
        case "AXWebArea":
            value += 35
        default:
            value += 20
        }

        if enabled == true || enabled == nil {
            value += 10
        } else {
            value -= 50
        }

        value += Self.hintScore(for: placeholder, weight: 45)
        value += Self.hintScore(for: title, weight: 28)
        value += Self.hintScore(for: description, weight: 28)
        value += Self.hintScore(for: roleDescription, weight: 12)

        if hasNegativeHint {
            value -= 80
        }

        return value
    }

    var isPlausibleComposer: Bool {
        score >= 90
    }

    var diagnostic: String {
        var parts = ["role=\(role ?? "unknown")", "score=\(score)"]
        if placeholder?.isEmpty == false {
            parts.append("placeholder")
        }
        if title?.isEmpty == false {
            parts.append("title")
        }
        if description?.isEmpty == false {
            parts.append("description")
        }
        return parts.joined(separator: " ")
    }

    private var isEditableRole: Bool {
        switch role {
        case kAXTextAreaRole, kAXTextFieldRole, "AXWebArea":
            true
        default:
            false
        }
    }

    private var hasNegativeHint: Bool {
        let text = searchableText
        let negativeHints = [
            "search",
            "filter",
            "find",
            "jump to",
            "command palette",
            "terminal",
            "shell",
            "path",
            "url",
            "filename",
            "file name",
            "sidebar",
            "title"
        ]
        return negativeHints.contains { text.contains($0) }
    }

    private var searchableText: String {
        [
            roleDescription,
            title,
            description,
            placeholder
        ]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
    }

    private static func hintScore(for text: String?, weight: Int) -> Int {
        guard let text = text?.lowercased(), !text.isEmpty else {
            return 0
        }

        let strongHints = [
            "message",
            "prompt",
            "ask",
            "composer",
            "chat",
            "reply",
            "send"
        ]
        if strongHints.contains(where: { text.contains($0) }) {
            return weight
        }

        let weakerHints = [
            "codex",
            "agent",
            "instruction",
            "input",
            "write"
        ]
        if weakerHints.contains(where: { text.contains($0) }) {
            return max(8, weight / 2)
        }

        return 0
    }
}

private struct ComposerFocusReport: Equatable {
    let focused: Bool
    let note: String
}

enum CodexAXHandoffConstants {
    static let manualAccessibilityAttribute = "AXManualAccessibility"
}

enum CodexPasteMenuScript {
    static func source(processName: String) -> String {
        let escapedProcessName = processName.appleScriptEscaped
        return """
        tell application "System Events"
            tell process "\(escapedProcessName)"
                set frontmost to true
                delay 0.15
                try
                    click menu item "Paste" of menu "Edit" of menu bar 1
                    return "ok"
                on error
                    try
                        click menu item "Paste" of menu 1 of menu bar item "Edit" of menu bar 1
                        return "ok"
                    on error errMsg number errNum
                        return "error " & errNum & ": " & errMsg
                    end try
                end try
            end tell
        end tell
        """
    }
}

enum CodexActivationScript {
    static func source(processName: String) -> String {
        let escapedProcessName = processName.appleScriptEscaped
        return """
        tell application "System Events"
            if exists process "\(escapedProcessName)" then
                tell process "\(escapedProcessName)"
                    set frontmost to true
                end tell
                return "ok"
            else
                return "missing"
            end if
        end tell
        """
    }
}

struct CodexComposerClickFallback: Equatable {
    static func clickPoint(in windowBounds: CGRect) -> CGPoint? {
        clickPoints(in: windowBounds).first
    }

    static func clickPoints(in windowBounds: CGRect) -> [CGPoint] {
        let bounds = windowBounds.standardized
        guard bounds.width >= 220, bounds.height >= 220 else {
            return []
        }

        let bottomOffset = min(max(bounds.height * 0.06, 48), 92)
        let lowerBandY = min(max(bounds.maxY - bottomOffset, bounds.minY + 120), bounds.maxY - 56)
        let mirroredBandY = min(max(bounds.minY + bottomOffset, bounds.minY + 56), bounds.maxY - 120)
        let xCandidates = [
            bounds.midX,
            bounds.minX + bounds.width * 0.38,
            bounds.minX + bounds.width * 0.62
        ]
        let yCandidates = [
            lowerBandY,
            lowerBandY - 34,
            lowerBandY + 34,
            mirroredBandY,
            mirroredBandY - 34,
            mirroredBandY + 34
        ]

        var points: [CGPoint] = []
        for y in yCandidates where y >= bounds.minY + 48 && y <= bounds.maxY - 48 {
            for x in xCandidates where x >= bounds.minX + 64 && x <= bounds.maxX - 64 {
                let point = CGPoint(x: x, y: y)
                if !points.contains(where: { abs($0.x - point.x) < 1 && abs($0.y - point.y) < 1 }) {
                    points.append(point)
                }
            }
        }
        return points
    }
}

struct CodexHandoffService {
    func handoff(
        pngData: Data,
        autoPaste: Bool,
        fileURL: URL? = nil,
        codexCLIPathOverride: String? = nil
    ) async -> HandoffReport {
        let bytes = copyToPasteboard(pngData: pngData, fileURL: fileURL)
        if bytes == 0 {
            return .init(
                result: .clipboardWriteFailed,
                codexFound: false,
                codexFocused: false,
                pasteShortcutPosted: false,
                bytesInPasteboard: 0,
                codexDescription: nil,
                note: "Clipboard write failed. No handoff was attempted.",
                appServerDiagnostics: nil
            )
        }

        guard autoPaste else {
            return .init(
                result: .copiedOnly,
                codexFound: false,
                codexFocused: false,
                pasteShortcutPosted: false,
                bytesInPasteboard: bytes,
                codexDescription: nil,
                note: fileURL == nil ? "PNG copied to clipboard." : "PNG and file URL copied to clipboard.",
                appServerDiagnostics: nil
            )
        }

        guard let codexApp = runningCodexTarget() else {
            return .init(
                result: .codexUnavailable,
                codexFound: false,
                codexFocused: false,
                pasteShortcutPosted: false,
                bytesInPasteboard: bytes,
                codexDescription: nil,
                note: "PNG copied. Codex was not running, so CueShot could not trigger Paste.",
                appServerDiagnostics: nil
            )
        }

        let description = describe(codexApp)
        guard await activateCodexForPaste(codexApp) else {
            return .init(
                result: .codexFocusFailed,
                codexFound: true,
                codexFocused: false,
                pasteShortcutPosted: false,
                bytesInPasteboard: bytes,
                codexDescription: description,
                note: "PNG copied. CueShot found Codex but it was not frontmost in time for Paste.",
                appServerDiagnostics: nil
            )
        }

        let composerFocus = await focusCodexComposerForPaste(codexApp)
        guard composerFocus.focused else {
            return .init(
                result: .codexPasteTargetUnavailable,
                codexFound: true,
                codexFocused: true,
                pasteShortcutPosted: false,
                bytesInPasteboard: bytes,
                codexDescription: description,
                note: "PNG copied. Codex was frontmost, but CueShot could not focus the prompt before Paste. \(composerFocus.note)",
                appServerDiagnostics: nil
            )
        }

        try? await Task.sleep(for: .milliseconds(160))
        let pasteDelivery = sendPasteCommand(to: codexApp)
        if pasteDelivery.posted {
            return .init(
                result: .pasteAttempted,
                codexFound: true,
                codexFocused: true,
                pasteShortcutPosted: true,
                bytesInPasteboard: bytes,
                codexDescription: description,
                note: "PNG copied, Codex focus step completed, and \(pasteDelivery.note) Verify the composer attached it. \(composerFocus.note)",
                appServerDiagnostics: nil
            )
        } else {
            return .init(
                result: .pasteEventBlocked,
                codexFound: true,
                codexFocused: true,
                pasteShortcutPosted: false,
                bytesInPasteboard: bytes,
                codexDescription: description,
                note: "PNG copied, but CueShot could not trigger Codex's Paste command.",
                appServerDiagnostics: nil
            )
        }
    }

    @discardableResult
    func copyToPasteboard(pngData: Data, fileURL: URL? = nil) -> Int {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if pngData.isEmpty {
            return 0
        }

        let pngItem = NSPasteboardItem()
        pngItem.setData(pngData, forType: .png)

        var objects: [NSPasteboardWriting] = [pngItem]
        if let fileURL {
            objects.append(fileURL as NSURL)
        }

        return pasteboard.writeObjects(objects) ? pngData.count : 0
    }

    func activateCodexApp() -> Bool {
        guard let codexApp = runningCodexTarget() else {
            return false
        }

        codexApp.unhide()
        return codexApp.activate(options: [.activateAllWindows])
    }

    func runningCodexDescription() -> String? {
        runningCodexTarget().map(describe)
    }

    private func runningCodexTarget() -> NSRunningApplication? {
        if let frontmost = NSWorkspace.shared.frontmostApplication, isCodexApp(frontmost) {
            return frontmost
        }

        let runningApplications = NSWorkspace.shared.runningApplications
        return runningApplications.first { $0.bundleIdentifier?.lowercased() == "com.openai.codex" }
            ?? runningApplications.first { $0.bundleURL?.lastPathComponent == "Codex.app" }
            ?? runningApplications.first { $0.localizedName == "Codex" }
    }

    private func isCodexApp(_ application: NSRunningApplication) -> Bool {
        CodexApplicationMatcher.isCodexDesktopTarget(
            localizedName: application.localizedName,
            bundleIdentifier: application.bundleIdentifier,
            bundleLastPathComponent: application.bundleURL?.lastPathComponent
        )
    }

    private func activateCodexForPaste(_ codexApp: NSRunningApplication) async -> Bool {
        codexApp.unhide()
        codexApp.activate(options: [.activateAllWindows])

        if await waitUntilCodexIsFrontmost(codexApp, timeout: 2.0) {
            return true
        }

        if activateCodexViaSystemEvents(codexApp),
           await waitUntilCodexIsFrontmost(codexApp, timeout: 2.0) {
            return true
        }

        guard let bundleURL = codexApp.bundleURL,
              await openCodexApplication(at: bundleURL)
        else {
            guard activateCodexViaSystemEvents(codexApp) else {
                return false
            }
            return await waitUntilCodexIsFrontmost(codexApp, timeout: 2.0)
        }

        if await waitUntilCodexIsFrontmost(codexApp, timeout: 3.0) {
            return true
        }

        guard activateCodexViaSystemEvents(codexApp) else {
            return false
        }
        return await waitUntilCodexIsFrontmost(codexApp, timeout: 2.0)
    }

    private func focusCodexComposerForPaste(_ codexApp: NSRunningApplication) async -> ComposerFocusReport {
        guard AXIsProcessTrusted() else {
            return .init(
                focused: false,
                note: "Accessibility permission is required to focus Codex's composer."
            )
        }

        let appElement = AXUIElementCreateApplication(codexApp.processIdentifier)
        AXUIElementSetMessagingTimeout(appElement, 0.25)

        let manualAccessibilityResult = enableManualAccessibility(on: appElement)
        let manualAccessibilityNote = "AXManualAccessibility=\(axErrorName(manualAccessibilityResult))"
        if manualAccessibilityResult == .success {
            try? await Task.sleep(for: .milliseconds(260))
        }

        if let candidate = verifiedFocusedComposer(in: appElement) {
            return .init(
                focused: true,
                note: "\(manualAccessibilityNote). Codex already had a verified prompt focused (\(candidate.diagnostic))."
            )
        }

        let roots = elementsAttribute(kAXWindowsAttribute, from: appElement)
        let searchRoots = roots.isEmpty ? [appElement] : roots
        guard let match = bestComposerElement(in: searchRoots) else {
            return await focusCodexComposerByClickingVisibleComposer(
                appElement: appElement,
                contextNote: "\(manualAccessibilityNote). No likely AX prompt was exposed."
            )
        }

        let focusResult = AXUIElementSetAttributeValue(
            match.element,
            kAXFocusedAttribute as CFString,
            kCFBooleanTrue
        )

        guard focusResult == .success else {
            let clickReport = await focusCodexComposerByClickingVisibleComposer(
                appElement: appElement,
                contextNote: "\(manualAccessibilityNote). Found a likely prompt (\(match.candidate.diagnostic)) but AX focus returned \(axErrorName(focusResult))."
            )
            if clickReport.focused {
                return clickReport
            }
            return .init(focused: false, note: clickReport.note)
        }

        if let verifiedCandidate = await waitForVerifiedComposerFocus(in: appElement, timeout: 1.0) {
            return .init(
                focused: true,
                note: "\(manualAccessibilityNote). Focused and verified Codex prompt (\(verifiedCandidate.diagnostic))."
            )
        }

        return await focusCodexComposerByClickingVisibleComposer(
            appElement: appElement,
            contextNote: "\(manualAccessibilityNote). AX focus was posted to a likely prompt (\(match.candidate.diagnostic)) but Codex did not report that prompt as focused."
        )
    }

    private func focusCodexComposerByClickingVisibleComposer(
        appElement: AXUIElement,
        contextNote: String
    ) async -> ComposerFocusReport {
        guard let windowBounds = bestCodexWindowBounds(from: appElement) else {
            return .init(
                focused: false,
                note: "\(contextNote) No Codex window bounds were exposed for click fallback."
            )
        }

        guard let clickPoint = CodexComposerClickFallback.clickPoint(in: windowBounds) else {
            return .init(
                focused: false,
                note: "\(contextNote) Codex window bounds were too small for the visible-composer click fallback."
            )
        }

        guard click(at: clickPoint) else {
            return .init(
                focused: false,
                note: "\(contextNote) CueShot could not create the visible-composer click fallback event."
            )
        }

        if let verifiedCandidate = await waitForVerifiedComposerFocus(in: appElement, timeout: 0.55) {
            return .init(
                focused: true,
                note: "\(contextNote) Click fallback verified Codex prompt focus (\(verifiedCandidate.diagnostic))."
            )
        }

        return .init(
            focused: true,
            note: "\(contextNote) Clicked Codex's lower composer area once; AX did not verify focus, so Paste will be attempted as a best-effort handoff."
        )
    }

    private func enableManualAccessibility(on appElement: AXUIElement) -> AXError {
        AXUIElementSetAttributeValue(
            appElement,
            CodexAXHandoffConstants.manualAccessibilityAttribute as CFString,
            kCFBooleanTrue
        )
    }

    private func verifiedFocusedComposer(in appElement: AXUIElement) -> CodexComposerCandidate? {
        guard let focusedElement = elementAttribute(kAXFocusedUIElementAttribute, from: appElement) else {
            return nil
        }

        let focusedCandidate = composerCandidate(for: focusedElement)
        if focusedCandidate.isPlausibleComposer {
            return focusedCandidate
        }

        return bestComposerElement(in: [focusedElement], maxElements: 120)?.candidate
    }

    private func waitForVerifiedComposerFocus(
        in appElement: AXUIElement,
        timeout: TimeInterval
    ) async -> CodexComposerCandidate? {
        let start = ProcessInfo.processInfo.systemUptime
        while ProcessInfo.processInfo.systemUptime - start <= timeout {
            if let candidate = verifiedFocusedComposer(in: appElement) {
                return candidate
            }
            try? await Task.sleep(for: .milliseconds(55))
        }

        return nil
    }

    private func waitUntilCodexIsFrontmost(_ codexApp: NSRunningApplication, timeout: TimeInterval = 3.0) async -> Bool {
        let start = ProcessInfo.processInfo.systemUptime
        while ProcessInfo.processInfo.systemUptime - start <= timeout {
            if let frontmost = NSWorkspace.shared.frontmostApplication, isCodexApp(frontmost) {
                return true
            }
            codexApp.activate(options: [.activateAllWindows])
            try? await Task.sleep(for: .milliseconds(50))
        }

        return false
    }

    private func bestComposerElement(
        in roots: [AXUIElement],
        maxElements: Int = 450
    ) -> (element: AXUIElement, candidate: CodexComposerCandidate)? {
        var queue = roots
        var visited = Set<CFHashCode>()
        var index = 0
        var bestMatch: (element: AXUIElement, candidate: CodexComposerCandidate)?

        while index < queue.count && visited.count < maxElements {
            let element = queue[index]
            index += 1

            let key = CFHash(element)
            guard visited.insert(key).inserted else {
                continue
            }

            let candidate = composerCandidate(for: element)
            if candidate.isPlausibleComposer,
               bestMatch == nil || candidate.score > bestMatch!.candidate.score {
                bestMatch = (element, candidate)
            }

            queue.append(contentsOf: elementsAttribute(kAXChildrenAttribute, from: element))
            queue.append(contentsOf: elementsAttribute(kAXVisibleChildrenAttribute, from: element))
            queue.append(contentsOf: elementsAttribute(kAXContentsAttribute, from: element))
        }

        return bestMatch
    }

    private func bestCodexWindowBounds(from appElement: AXUIElement) -> CGRect? {
        let directWindows = [
            elementAttribute(kAXFocusedWindowAttribute, from: appElement),
            elementAttribute(kAXMainWindowAttribute, from: appElement)
        ].compactMap { $0 }

        if let bounds = directWindows.compactMap(bounds(for:)).first(where: isUsableCodexWindow) {
            return bounds
        }

        return elementsAttribute(kAXWindowsAttribute, from: appElement)
            .compactMap(bounds(for:))
            .filter(isUsableCodexWindow)
            .max { ($0.width * $0.height) < ($1.width * $1.height) }
    }

    private func isUsableCodexWindow(_ rect: CGRect) -> Bool {
        rect.width >= 360 && rect.height >= 360
    }

    private func axErrorName(_ error: AXError) -> String {
        switch error {
        case .success:
            "success"
        case .failure:
            "failure"
        case .illegalArgument:
            "illegalArgument"
        case .invalidUIElement:
            "invalidUIElement"
        case .invalidUIElementObserver:
            "invalidUIElementObserver"
        case .cannotComplete:
            "cannotComplete"
        case .attributeUnsupported:
            "attributeUnsupported"
        case .actionUnsupported:
            "actionUnsupported"
        case .notificationUnsupported:
            "notificationUnsupported"
        case .notImplemented:
            "notImplemented"
        case .notificationAlreadyRegistered:
            "notificationAlreadyRegistered"
        case .notificationNotRegistered:
            "notificationNotRegistered"
        case .apiDisabled:
            "apiDisabled"
        case .noValue:
            "noValue"
        case .parameterizedAttributeUnsupported:
            "parameterizedAttributeUnsupported"
        case .notEnoughPrecision:
            "notEnoughPrecision"
        @unknown default:
            "unknown"
        }
    }

    private func bounds(for element: AXUIElement) -> CGRect? {
        guard
            let position = pointAttribute(kAXPositionAttribute, from: element),
            let size = sizeAttribute(kAXSizeAttribute, from: element),
            size.width > 1,
            size.height > 1
        else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    private func composerCandidate(for element: AXUIElement) -> CodexComposerCandidate {
        CodexComposerCandidate(
            role: stringAttribute(kAXRoleAttribute, from: element),
            subrole: stringAttribute(kAXSubroleAttribute, from: element),
            roleDescription: stringAttribute(kAXRoleDescriptionAttribute, from: element),
            title: stringAttribute(kAXTitleAttribute, from: element),
            description: stringAttribute(kAXDescriptionAttribute, from: element),
            placeholder: stringAttribute(kAXPlaceholderValueAttribute, from: element),
            enabled: boolAttribute(kAXEnabledAttribute, from: element)
        )
    }

    private func elementAttribute(_ name: String, from element: AXUIElement) -> AXUIElement? {
        var rawValue: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, name as CFString, &rawValue)
        guard error == .success, let value = rawValue else {
            return nil
        }
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return (value as! AXUIElement)
    }

    private func elementsAttribute(_ name: String, from element: AXUIElement) -> [AXUIElement] {
        var rawValue: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, name as CFString, &rawValue)
        guard error == .success, let value = rawValue else {
            return []
        }
        return value as? [AXUIElement] ?? []
    }

    private func stringAttribute(_ name: String, from element: AXUIElement) -> String? {
        var rawValue: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, name as CFString, &rawValue)
        guard error == .success, let value = rawValue else {
            return nil
        }
        return value as? String
    }

    private func boolAttribute(_ name: String, from element: AXUIElement) -> Bool? {
        var rawValue: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, name as CFString, &rawValue)
        guard error == .success, let value = rawValue else {
            return nil
        }
        return value as? Bool
    }

    private func pointAttribute(_ name: String, from element: AXUIElement) -> CGPoint? {
        var rawValue: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, name as CFString, &rawValue)
        guard error == .success, let value = rawValue else {
            return nil
        }

        var point = CGPoint.zero
        guard CFGetTypeID(value) == AXValueGetTypeID(),
              AXValueGetValue((value as! AXValue), .cgPoint, &point)
        else {
            return nil
        }

        return point
    }

    private func sizeAttribute(_ name: String, from element: AXUIElement) -> CGSize? {
        var rawValue: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, name as CFString, &rawValue)
        guard error == .success, let value = rawValue else {
            return nil
        }

        var size = CGSize.zero
        guard CFGetTypeID(value) == AXValueGetTypeID(),
              AXValueGetValue((value as! AXValue), .cgSize, &size)
        else {
            return nil
        }

        return size
    }

    private func openCodexApplication(at bundleURL: URL) async -> Bool {
        await withCheckedContinuation { continuation in
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            configuration.addsToRecentItems = false
            configuration.createsNewApplicationInstance = false

            NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { application, error in
                continuation.resume(returning: application != nil && error == nil)
            }
        }
    }

    private func describe(_ application: NSRunningApplication) -> String {
        let name = application.localizedName ?? "Unknown app"
        let bundle = application.bundleIdentifier ?? "no bundle id"
        let path = application.bundleURL?.path ?? "unknown path"
        return "\(name) [\(bundle)] at \(path)"
    }

    private func sendPasteShortcut() -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    private func sendPasteCommand(to codexApp: NSRunningApplication) -> (posted: Bool, note: String) {
        if sendPasteViaEditMenu(codexApp) {
            return (true, "Codex Edit > Paste was triggered.")
        }

        if sendPasteShortcut() {
            return (true, "Codex Edit > Paste failed, so Cmd+V was posted as fallback.")
        }

        return (false, "Codex Edit > Paste and Cmd+V fallback both failed.")
    }

    private func sendPasteViaEditMenu(_ codexApp: NSRunningApplication) -> Bool {
        let processName = codexApp.localizedName ?? "Codex"
        guard let appleScript = NSAppleScript(source: CodexPasteMenuScript.source(processName: processName)) else {
            return false
        }

        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        guard error == nil else {
            return false
        }

        return result.stringValue == "ok"
    }

    private func activateCodexViaSystemEvents(_ codexApp: NSRunningApplication) -> Bool {
        let processName = codexApp.localizedName ?? "Codex"
        guard let appleScript = NSAppleScript(source: CodexActivationScript.source(processName: processName)) else {
            return false
        }

        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        guard error == nil else {
            return false
        }

        return result.stringValue == "ok"
    }

    private func click(at point: CGPoint) -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        guard
            let mouseDown = CGEvent(
                mouseEventSource: source,
                mouseType: .leftMouseDown,
                mouseCursorPosition: point,
                mouseButton: .left
            ),
            let mouseUp = CGEvent(
                mouseEventSource: source,
                mouseType: .leftMouseUp,
                mouseCursorPosition: point,
                mouseButton: .left
            )
        else {
            return false
        }

        mouseDown.post(tap: .cghidEventTap)
        mouseUp.post(tap: .cghidEventTap)
        return true
    }
}

private extension String {
    var appleScriptEscaped: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

extension HandoffResult {
    var didAttemptPaste: Bool { self == .pasteAttempted || self == .sentVerified }
    var isVerifiedSent: Bool { self == .sentVerified }
    var isAppServerAccepted: Bool { self == .codexAppServerAccepted }

    var displayTitle: String {
        switch self {
        case .copiedOnly:
            "Copied to Clipboard"
        case .clipboardWriteFailed:
            "Clipboard failed"
        case .codexUnavailable:
            "Codex unavailable"
        case .codexFocusFailed:
            "Codex focus failed"
        case .codexPasteTargetUnavailable:
            "Codex prompt not focused"
        case .codexAppServerUnavailable:
            "Codex App Server unavailable"
        case .codexAppServerFailed:
            "Codex App Server failed"
        case .pasteEventBlocked:
            "Paste blocked"
        case .pasteAttempted:
            "Paste attempted"
        case .codexAppServerAccepted:
            "Sent to Codex App Server"
        case .sentVerified:
            "Sent to Codex"
        }
    }

    var historyStatus: String {
        switch self {
        case .copiedOnly:
            "Copied"
        case .clipboardWriteFailed:
            "Clipboard failed"
        case .codexUnavailable:
            "Codex unavailable"
        case .codexFocusFailed:
            "Codex focus failed"
        case .codexPasteTargetUnavailable:
            "Codex prompt not focused"
        case .codexAppServerUnavailable:
            "App Server unavailable"
        case .codexAppServerFailed:
            "App Server failed"
        case .pasteEventBlocked:
            "Paste blocked"
        case .pasteAttempted:
            "Paste attempted"
        case .codexAppServerAccepted:
            "App Server accepted"
        case .sentVerified:
            "Sent to Codex"
        }
    }
}
