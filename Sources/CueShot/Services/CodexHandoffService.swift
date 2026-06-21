import AppKit
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

struct CodexHandoffService {
    private let appServerClient = CodexAppServerClient()

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

        guard let fileURL else {
            return .init(
                result: .codexAppServerFailed,
                codexFound: false,
                codexFocused: false,
                pasteShortcutPosted: false,
                bytesInPasteboard: bytes,
                codexDescription: nil,
                note: "CueShot copied the PNG, but no saved file path was available for Codex App Server.",
                appServerDiagnostics: nil
            )
        }

        let prompt = "Review this CueShot screenshot and help me with what it shows."
        let result = await appServerClient.sendLocalImage(
            fileURL: fileURL,
            prompt: prompt,
            cliPathOverride: codexCLIPathOverride
        )

        switch result {
        case .success(let sendResult):
            let turnSuffix = sendResult.turnID.map { " turn=\($0)" } ?? ""
            return .init(
                result: .codexAppServerAccepted,
                codexFound: false,
                codexFocused: false,
                pasteShortcutPosted: false,
                bytesInPasteboard: bytes,
                codexDescription: "App Server thread=\(sendResult.threadID)\(turnSuffix)",
                note: "Codex App Server accepted the image in a new App Server thread. If it does not appear in the visible Codex window, drag the PNG from history.",
                appServerDiagnostics: sendResult.diagnostics
            )
        case .failure(let error):
            let status: HandoffResult
            switch error {
            case .launchFailed, .timeout:
                status = .codexAppServerUnavailable
            case .fileMissing, .protocolError, .serverError:
                status = .codexAppServerFailed
            }
            return .init(
                result: status,
                codexFound: false,
                codexFocused: false,
                pasteShortcutPosted: false,
                bytesInPasteboard: bytes,
                codexDescription: nil,
                note: "\(error.localizedDescription) PNG and file URL remain on the clipboard for drag/drop.",
                appServerDiagnostics: error.diagnostics
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

        codexApp.activate(options: [.activateAllWindows])
        return true
    }

    func runningCodexDescription() -> String? {
        runningCodexTarget().map(describe)
    }

    private func runningCodexTarget() -> NSRunningApplication? {
        if let frontmost = NSWorkspace.shared.frontmostApplication, isCodexApp(frontmost) {
            return frontmost
        }

        return NSWorkspace.shared.runningApplications.first(where: isCodexApp)
    }

    private func isCodexApp(_ application: NSRunningApplication) -> Bool {
        if application.bundleIdentifier == "com.openai.codex" {
            return true
        }

        if let bundleID = application.bundleIdentifier?.lowercased(), bundleID.contains("codex") {
            return true
        }

        return application.localizedName == "Codex"
            || application.bundleURL?.lastPathComponent == "Codex.app"
    }

    private func describe(_ application: NSRunningApplication) -> String {
        let name = application.localizedName ?? "Unknown app"
        let bundle = application.bundleIdentifier ?? "no bundle id"
        let path = application.bundleURL?.path ?? "unknown path"
        return "\(name) [\(bundle)] at \(path)"
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
