import AppKit
import Foundation

struct CodexHandoffService {
    func handoff(pngData: Data, autoPaste: Bool) -> HandoffResult {
        copyToPasteboard(pngData: pngData)

        guard autoPaste, let codexApp = frontmostCodexTarget() ?? anyCodexTarget() else {
            return .copied
        }

        codexApp.activate(options: [.activateAllWindows])
        Thread.sleep(forTimeInterval: 0.16)
        sendPasteShortcut()
        return .sent
    }

    func copyToPasteboard(pngData: Data) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(pngData, forType: .png)
    }

    func activateCodexApp() -> Bool {
        guard let codexApp = frontmostCodexTarget() ?? anyCodexTarget() else {
            return false
        }

        codexApp.activate(options: [.activateAllWindows])
        return true
    }

    private func frontmostCodexTarget() -> NSRunningApplication? {
        if let frontmost = NSWorkspace.shared.frontmostApplication, isCodexLike(frontmost) {
            return frontmost
        }

        return nil
    }

    private func anyCodexTarget() -> NSRunningApplication? {
        return NSWorkspace.shared.runningApplications.first(where: isCodexLike)
    }

    private func isCodexLike(_ application: NSRunningApplication) -> Bool {
        let haystacks = [
            application.localizedName,
            application.bundleIdentifier
        ]
        .compactMap { $0?.lowercased() }

        return haystacks.contains { value in
            value.contains("codex") ||
            value.contains("chatgpt") ||
            value.contains("openai")
        }
    }

    private func sendPasteShortcut() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
