import ApplicationServices
import CoreGraphics
import Foundation
import AppKit

struct PermissionService {
    func currentStatus() -> PermissionStatus {
        PermissionStatus(
            accessibilityGranted: AXIsProcessTrusted(),
            screenRecordingGranted: CGPreflightScreenCaptureAccess()
        )
    }

    func requestAccessibilityPrompt() {
        let options = ["AXTrustedCheckOptionPrompt" as CFString: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func requestScreenRecordingPrompt() {
        CGRequestScreenCaptureAccess()
    }

    func openSettings(for kind: PermissionKind) {
        let urlString: String

        switch kind {
        case .accessibility:
            requestAccessibilityPrompt()
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .screenRecording:
            requestScreenRecordingPrompt()
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        }

        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
