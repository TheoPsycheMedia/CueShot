import AppKit
import Foundation
import XCTest
@testable import CueShot

final class HandoffTruthTests: XCTestCase {
    func testCodexMatcherOnlyTargetsRealCodexDesktopApp() {
        XCTAssertTrue(CodexApplicationMatcher.isCodexDesktopTarget(
            localizedName: "Codex",
            bundleIdentifier: "com.openai.codex",
            bundleLastPathComponent: "Codex.app"
        ))
        XCTAssertTrue(CodexApplicationMatcher.isCodexDesktopTarget(
            localizedName: nil,
            bundleIdentifier: nil,
            bundleLastPathComponent: "Codex.app"
        ))
        XCTAssertTrue(CodexApplicationMatcher.isCodexDesktopTarget(
            localizedName: "Codex",
            bundleIdentifier: nil,
            bundleLastPathComponent: nil
        ))
    }

    func testCodexMatcherRejectsOtherOpenAIAndCodexNamedApps() {
        XCTAssertFalse(CodexApplicationMatcher.isCodexDesktopTarget(
            localizedName: "ChatGPT Atlas",
            bundleIdentifier: "com.openai.atlas",
            bundleLastPathComponent: "ChatGPT Atlas.app"
        ))
        XCTAssertFalse(CodexApplicationMatcher.isCodexDesktopTarget(
            localizedName: "ChatGPT",
            bundleIdentifier: "com.openai.chat",
            bundleLastPathComponent: "ChatGPT.app"
        ))
        XCTAssertFalse(CodexApplicationMatcher.isCodexDesktopTarget(
            localizedName: "Codex Meter",
            bundleIdentifier: "dev.opensource.codexmeter",
            bundleLastPathComponent: "CodexMeter.app"
        ))
    }

    func testPasteAttemptedSummaryDoesNotClaimVerifiedSent() {
        let report = HandoffReport(
            result: .pasteAttempted,
            codexFound: true,
            codexFocused: true,
            pasteShortcutPosted: true,
            bytesInPasteboard: 1234,
            codexDescription: "Codex [com.openai.codex] at /Applications/Codex.app",
            note: "Cmd+V was posted to Codex. CueShot cannot verify the image attached."
        )

        XCTAssertTrue(report.summary.contains("Paste attempted"))
        XCTAssertFalse(report.summary.contains("Sent to Codex"))
        XCTAssertEqual(report.result.historyStatus, "Paste attempted")
    }

    func testCopiedOnlyHandoffKeepsClipboardLanguage() {
        let report = HandoffReport(
            result: .copiedOnly,
            codexFound: false,
            codexFocused: false,
            pasteShortcutPosted: false,
            bytesInPasteboard: 2048,
            codexDescription: nil,
            note: "PNG and file URL copied to clipboard."
        )

        XCTAssertEqual(report.result.displayTitle, "Copied to Clipboard")
        XCTAssertEqual(report.result.historyStatus, "Copied")
        XCTAssertFalse(report.result.didAttemptPaste)
        XCTAssertFalse(report.summary.contains("Sent to Codex"))
        XCTAssertFalse(report.summary.contains("App Server"))
    }

    func testCopiedStateLanguageDoesNotClaimVisibleCodexDelivery() {
        let state = CaptureState.copied(reason: "PNG copied. Press Cmd+V in Codex or drag the preview.")

        XCTAssertEqual(state.label, "Copied")
        XCTAssertTrue(state.detail.contains("PNG copied"))
        XCTAssertTrue(state.detail.contains("Cmd+V"))
        XCTAssertTrue(state.detail.contains("drag the preview"))
        XCTAssertFalse(state.detail.contains("Sent to Codex"))
        XCTAssertFalse(state.detail.contains("App Server accepted"))
    }

    func testFocusFailureReportKeepsCopiedLanguage() {
        let report = HandoffReport(
            result: .codexFocusFailed,
            codexFound: true,
            codexFocused: false,
            pasteShortcutPosted: false,
            bytesInPasteboard: 2048,
            codexDescription: "Codex [com.openai.codex] at /Applications/Codex.app",
            note: "PNG copied. CueShot found Codex but it was not frontmost in time for Cmd+V."
        )

        XCTAssertEqual(report.result.historyStatus, "Codex focus failed")
        XCTAssertFalse(report.result.didAttemptPaste)
        XCTAssertTrue(report.summary.contains("PNG copied"))
    }

    func testPromptFocusFailureReportKeepsCopiedLanguage() {
        let report = HandoffReport(
            result: .codexPasteTargetUnavailable,
            codexFound: true,
            codexFocused: true,
            pasteShortcutPosted: false,
            bytesInPasteboard: 2048,
            codexDescription: "Codex [com.openai.codex] at /Applications/Codex.app",
            note: "PNG copied. Codex was frontmost, but CueShot could not focus the prompt before Cmd+V."
        )

        XCTAssertEqual(report.result.historyStatus, "Codex prompt not focused")
        XCTAssertFalse(report.result.didAttemptPaste)
        XCTAssertTrue(report.summary.contains("PNG copied"))
        XCTAssertFalse(report.summary.contains("Paste attempted"))
    }

    func testComposerCandidateAcceptsPromptLikeTextArea() {
        let candidate = CodexComposerCandidate(
            role: "AXTextArea",
            roleDescription: "text area",
            placeholder: "Message Codex",
            enabled: true
        )

        XCTAssertTrue(candidate.isPlausibleComposer)
        XCTAssertGreaterThanOrEqual(candidate.score, 90)
    }

    func testComposerCandidateRejectsSearchField() {
        let candidate = CodexComposerCandidate(
            role: "AXTextField",
            title: "Search threads",
            placeholder: "Search",
            enabled: true
        )

        XCTAssertFalse(candidate.isPlausibleComposer)
    }

    func testComposerCandidateRejectsTerminalTextArea() {
        let candidate = CodexComposerCandidate(
            role: "AXTextArea",
            title: "Terminal",
            description: "Shell input",
            enabled: true
        )

        XCTAssertFalse(candidate.isPlausibleComposer)
    }

    func testManualAccessibilityAttributeMatchesElectronOverride() {
        XCTAssertEqual(CodexAXHandoffConstants.manualAccessibilityAttribute, "AXManualAccessibility")
    }

    func testAppleScriptPasteCommandIsParseable() throws {
        let source = CodexPasteMenuScript.source(processName: "Codex")
        let script = try XCTUnwrap(NSAppleScript(source: source))
        var error: NSDictionary?

        XCTAssertTrue(script.compileAndReturnError(&error), "\(error ?? [:])")
        XCTAssertTrue(source.contains("click menu item \"Paste\""))
        XCTAssertTrue(source.contains("menu bar item \"Edit\""))
    }

    func testAppleScriptPasteCommandEscapesProcessName() {
        let source = CodexPasteMenuScript.source(processName: #"Codex "Beta"\Helper"#)

        XCTAssertTrue(source.contains(#"tell process "Codex \"Beta\"\\Helper""#))
    }

    func testSystemEventsAutomationConsentScriptIsParseable() throws {
        let source = SystemEventsAutomationConsentScript.source
        let script = try XCTUnwrap(NSAppleScript(source: source))
        var error: NSDictionary?

        XCTAssertTrue(script.compileAndReturnError(&error), "\(error ?? [:])")
        XCTAssertTrue(source.contains("System Events"))
        XCTAssertTrue(source.contains("count of processes"))
    }

    func testAppleScriptActivationCommandIsParseable() throws {
        let source = CodexActivationScript.source(processName: "Codex")
        let script = try XCTUnwrap(NSAppleScript(source: source))
        var error: NSDictionary?

        XCTAssertTrue(script.compileAndReturnError(&error), "\(error ?? [:])")
        XCTAssertTrue(source.contains("set frontmost to true"))
        XCTAssertTrue(source.contains("return \"ok\""))
    }

    func testAppleScriptActivationCommandEscapesProcessName() {
        let source = CodexActivationScript.source(processName: #"Codex "Beta"\Helper"#)

        XCTAssertTrue(source.contains(#"exists process "Codex \"Beta\"\\Helper""#))
        XCTAssertTrue(source.contains(#"tell process "Codex \"Beta\"\\Helper""#))
    }

    func testVisibleComposerClickFallbackTargetsLowerCenterOfWindow() {
        let bounds = CGRect(x: 100, y: 80, width: 1200, height: 900)
        let point = CodexComposerClickFallback.clickPoint(in: bounds)

        XCTAssertEqual(point?.x, bounds.midX)
        XCTAssertNotNil(point)
        XCTAssertGreaterThan(point!.y, bounds.maxY - 100)
        XCTAssertLessThan(point!.y, bounds.maxY - 40)
    }

    func testVisibleComposerClickFallbackProvidesSearchGrid() {
        let bounds = CGRect(x: 100, y: 80, width: 1200, height: 900)
        let points = CodexComposerClickFallback.clickPoints(in: bounds)

        XCTAssertGreaterThan(points.count, 6)
        XCTAssertEqual(points.first?.x, bounds.midX)
        XCTAssertTrue(points.contains { $0.x < bounds.midX && $0.y > bounds.midY })
        XCTAssertTrue(points.contains { $0.x > bounds.midX && $0.y > bounds.midY })
        XCTAssertTrue(points.contains { $0.y < bounds.midY })
    }

    func testVisibleComposerClickFallbackRejectsTinyWindow() {
        XCTAssertNil(CodexComposerClickFallback.clickPoint(in: CGRect(x: 0, y: 0, width: 180, height: 180)))
        XCTAssertTrue(CodexComposerClickFallback.clickPoints(in: CGRect(x: 0, y: 0, width: 180, height: 180)).isEmpty)
    }

    func testAppServerAcceptedDoesNotClaimVisiblePaste() {
        let report = HandoffReport(
            result: .codexAppServerAccepted,
            codexFound: false,
            codexFocused: false,
            pasteShortcutPosted: false,
            bytesInPasteboard: 4096,
            codexDescription: "App Server thread=abc turn=def",
            note: "Codex App Server accepted the image in a new App Server thread."
        )

        XCTAssertEqual(report.result.displayTitle, "Sent to Codex App Server")
        XCTAssertEqual(report.result.historyStatus, "App Server accepted")
        XCTAssertTrue(report.result.isAppServerAccepted)
        XCTAssertFalse(report.result.didAttemptPaste)
        XCTAssertTrue(report.summary.contains("App Server thread=abc"))
        XCTAssertFalse(report.summary.contains("Paste attempted"))
    }

    func testCaptureStatePasteAttemptedIsHonestAboutVerification() {
        XCTAssertEqual(CaptureState.pasteAttempted.label, "Paste Attempted")
        XCTAssertTrue(CaptureState.pasteAttempted.detail.contains("Verify Codex attached it"))
    }

    func testTurnStartPayloadIncludesLocalImageAndTextElements() {
        let params = CodexAppServerClient.makeTurnStartParams(
            threadID: "thread-123",
            prompt: "Inspect this image.",
            imagePath: "/tmp/cueshot.png"
        )

        XCTAssertEqual(params["threadId"] as? String, "thread-123")
        let input = params["input"] as? [[String: Any]]
        XCTAssertEqual(input?.count, 2)
        XCTAssertEqual(input?.first?["type"] as? String, "text")
        XCTAssertEqual(input?.first?["text"] as? String, "Inspect this image.")
        XCTAssertNotNil(input?.first?["text_elements"] as? [Any])
        XCTAssertEqual(input?.last?["type"] as? String, "localImage")
        XCTAssertEqual(input?.last?["path"] as? String, "/tmp/cueshot.png")
    }

    func testCaptureDragPayloadPublishesExistingPNGAsFileURLAndPNGData() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CueShotDragPayload-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let pngURL = directory.appendingPathComponent("capture.png")
        let pngData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        try pngData.write(to: pngURL)

        let item = try XCTUnwrap(CaptureDragPayload.makePasteboardItem(fileURL: pngURL))

        XCTAssertEqual(item.string(forType: .fileURL), pngURL.absoluteString)
        XCTAssertEqual(item.string(forType: .string), pngURL.path)
        XCTAssertEqual(item.string(forType: .init("public.url-name")), "capture.png")
        XCTAssertEqual(item.data(forType: .png), pngData)
    }

    func testCaptureDragPayloadRejectsMissingFile() {
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).png")

        XCTAssertNil(CaptureDragPayload.makePasteboardItem(fileURL: missingURL))
    }

    func testInitializePayloadDeclaresCapabilities() {
        let params = CodexAppServerClient.makeInitializeParams(version: "test")
        let clientInfo = params["clientInfo"] as? [String: Any]
        let capabilities = params["capabilities"] as? [String: Any]

        XCTAssertEqual(clientInfo?["name"] as? String, "cueshot")
        XCTAssertEqual(clientInfo?["version"] as? String, "test")
        XCTAssertEqual(capabilities?["experimentalApi"] as? Bool, false)
        XCTAssertEqual(capabilities?["requestAttestation"] as? Bool, false)
        XCTAssertNotNil(capabilities?["optOutNotificationMethods"] as? NSNull)
    }

    func testLegacyHistoryStatusesDisplayAsClipboardFirst() {
        let pasteAttempt = CaptureRecord(
            id: UUID(),
            createdAt: .now,
            mode: .element,
            confidence: "Exact",
            sourceAppName: "Codex",
            axRole: "AXWindow",
            dimensions: "316 x 92",
            fileSize: "28 KB",
            handoffStatus: "Paste attempted",
            pngRelativePath: nil
        )
        let focusFailed = pasteAttempt.withHandoffStatus("Codex focus failed")

        XCTAssertEqual(pasteAttempt.displayHandoffStatus, "Copied to Clipboard")
        XCTAssertEqual(focusFailed.displayHandoffStatus, "Copied to Clipboard")
    }
}
