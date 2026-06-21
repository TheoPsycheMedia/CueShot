import Foundation
import XCTest
@testable import CueShot

final class HandoffTruthTests: XCTestCase {
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

    func testReadyToDragCopyLanguageDoesNotClaimVisibleCodexDelivery() {
        let state = CaptureState.readyToDrag(reason: "PNG copied. Press Cmd+V in Codex or drag the preview.")

        XCTAssertEqual(state.label, "Ready to Drag")
        XCTAssertTrue(state.detail.contains("PNG copied"))
        XCTAssertTrue(state.detail.contains("Cmd+V"))
        XCTAssertTrue(state.detail.contains("drag the preview"))
        XCTAssertFalse(state.detail.contains("Sent to Codex"))
        XCTAssertFalse(state.detail.contains("App Server accepted"))
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
