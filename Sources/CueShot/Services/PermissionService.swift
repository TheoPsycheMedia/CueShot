import ApplicationServices
import Carbon
import CoreGraphics
import Foundation
import AppKit

struct PermissionService {
    func currentStatus() -> PermissionStatus {
        PermissionStatus(
            accessibilityGranted: AXIsProcessTrusted(),
            screenRecordingGranted: CGPreflightScreenCaptureAccess(),
            automationStatus: automationPermissionStatus(prompt: false)
        )
    }

    func requestAccessibilityPrompt() {
        let options = ["AXTrustedCheckOptionPrompt" as CFString: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func requestScreenRecordingPrompt() {
        CGRequestScreenCaptureAccess()
    }

    func requestAutomationPrompt() {
        _ = automationPermissionStatus(prompt: true)
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
        case .automation:
            requestAutomationPrompt()
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        }

        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    private func automationPermissionStatus(prompt: Bool) -> AutomationPermissionStatus {
        let descriptor = NSAppleEventDescriptor(bundleIdentifier: "com.apple.systemevents")
        guard let aeDesc = descriptor.aeDesc else {
            return .unknown
        }

        var target = aeDesc.pointee
        let status = AEDeterminePermissionToAutomateTarget(
            &target,
            typeWildCard,
            typeWildCard,
            prompt
        )

        switch status {
        case noErr:
            return .granted
        case OSStatus(errAEEventWouldRequireUserConsent):
            return .notDetermined
        case OSStatus(errAEEventNotPermitted):
            return .denied
        default:
            return .unknown
        }
    }
}
