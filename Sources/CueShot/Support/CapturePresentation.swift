import AppKit
import SwiftUI

/// Human-facing copy and lightweight presentation helpers for CueShot's UI.
/// Keep capture behavior in AppModel/services. This layer only translates state into user language.
enum CaptureCopy {
    static let emptyTitle = "No captures yet"
    static let emptyDetail = "Choose a mode, then capture. Your recent captures will appear here."
    static let copiedTitle = "Copied to clipboard"
    static let copiedDetail = "Paste it anywhere, drag the preview, or save a copy."
    static let codexPasteDetail = "Paste in Codex when you’re ready."
    static let visiblePasteSent = "Paste command sent, check Codex"
    static let visiblePasteHonesty = "CueShot copied the image first. If it tried a visible Paste command, confirm the image appears before sending your message."
    static let textFoundTitle = "Text found"
    static let textFoundDetail = "Review it below, then copy it wherever you need it."
    static let noTextTitle = "No text found"
    static let noTextDetail = "Try capturing a tighter area with larger, clearer text."
    static let failedTitle = "Couldn’t capture that"
    static let failedDetail = "Try again, or open Details if this keeps happening."
    static let permissionSetupTitle = "A quick setup before your first capture"
    static let permissionSetupDetail = "CueShot captures on your Mac and keeps your screenshots local. macOS requires two permissions for exact capture."
}

struct CaptureModePresentation: Equatable {
    let title: String
    let shortTitle: String
    let symbol: String
    let idleInstruction: String
    let armedInstruction: String
    let contextualHint: String?
    let helpText: String

    init(mode: CaptureMode) {
        symbol = mode.symbol
        switch mode {
        case .element:
            title = "Element"
            shortTitle = "Element"
            idleInstruction = "Capture a precise interface item under your cursor."
            armedInstruction = "Click the button, panel, or field you want."
            contextualHint = "Scroll to fine-tune the frame."
            helpText = "Capture a precise interface item when macOS exposes useful bounds."
        case .selection:
            title = "Selection"
            shortTitle = "Select"
            idleInstruction = "Capture a useful area around your next click."
            armedInstruction = "Click the area you want CueShot to frame."
            contextualHint = "Choose Area when you need exact boundaries."
            helpText = "CueShot chooses a nearby region around your click."
        case .area:
            title = "Area"
            shortTitle = "Area"
            idleInstruction = "Drag to choose exactly what to capture."
            armedInstruction = "Drag to select an area."
            contextualHint = "Press Esc to cancel."
            helpText = "Draw the exact rectangle you want to capture."
        case .window:
            title = "Window"
            shortTitle = "Window"
            idleInstruction = "Capture a whole window."
            armedInstruction = "Click anywhere in the window you want."
            contextualHint = nil
            helpText = "Capture the window containing your click."
        case .screen:
            title = "Screen"
            shortTitle = "Screen"
            idleInstruction = "Capture the current display."
            armedInstruction = "Click the display you want to capture."
            contextualHint = nil
            helpText = "Capture the display you click."
        case .ocr:
            title = "Text"
            shortTitle = "Text"
            idleInstruction = "Copy text from part of the screen."
            armedInstruction = "Click the text you want to copy."
            contextualHint = "CueShot also keeps the captured image."
            helpText = "Capture a region and copy recognized text from it."
        }
    }
}

extension CaptureMode {
    var presentation: CaptureModePresentation { CaptureModePresentation(mode: self) }
    var userFacingTitle: String { presentation.title }
    var userFacingPickerTitle: String { presentation.shortTitle }
    var userFacingHelpText: String { presentation.helpText }
    var userFacingIdleInstruction: String { presentation.idleInstruction }
    var userFacingArmedInstruction: String { presentation.armedInstruction }
}

struct PermissionPresentation: Equatable {
    let title: String
    let detail: String
    let actionTitle: String
    let systemImage: String
    let isRequired: Bool

    init(kind: PermissionKind) {
        isRequired = kind.isRequiredForCapture
        switch kind {
        case .screenRecording:
            title = "Allow Screen Recording"
            detail = "CueShot needs this to capture what is visible on your screen."
            actionTitle = "Open System Settings"
            systemImage = "rectangle.on.rectangle"
        case .accessibility:
            title = "Allow Accessibility"
            detail = "CueShot uses this to identify what is under your cursor and listen for the click that takes the capture."
            actionTitle = "Open System Settings"
            systemImage = "cursorarrow.motionlines"
        case .automation:
            title = "Codex Handoff"
            detail = "Optional. CueShot can send a visible Paste command after copying, but Codex still decides whether the image is attached."
            actionTitle = "Test Paste in Codex"
            systemImage = "keyboard"
        }
    }
}

extension PermissionKind {
    var presentation: PermissionPresentation { PermissionPresentation(kind: self) }
}

struct CaptureResultPresentation: Equatable {
    let title: String
    let detail: String
    let primaryActionTitle: String
    let secondaryActionTitle: String
    let isTextResult: Bool
    let ocrPreview: String?

    init(capture: CaptureRecord) {
        ocrPreview = capture.normalizedOCRText
        isTextResult = capture.mode == .ocr && capture.normalizedOCRText != nil
        if isTextResult {
            title = CaptureCopy.textFoundTitle
            detail = CaptureCopy.textFoundDetail
            primaryActionTitle = "Copy Text"
            secondaryActionTitle = "Copy Image"
        } else if capture.mode == .ocr {
            title = CaptureCopy.noTextTitle
            detail = CaptureCopy.noTextDetail
            primaryActionTitle = "Try Again"
            secondaryActionTitle = "Keep Image"
        } else {
            title = CaptureCopy.copiedTitle
            detail = CaptureCopy.copiedDetail
            primaryActionTitle = "Copy Again"
            secondaryActionTitle = "Save…"
        }
    }
}

extension CaptureState {
    var userFacingLabel: String {
        switch self {
        case .ready:
            "Ready to capture"
        case .armed:
            "Capture active"
        case .selectingArea:
            "Drag to select an area"
        case .capturing:
            "Capturing…"
        case .pasteAttempted:
            CaptureCopy.visiblePasteSent
        case .codexAppServerAccepted:
            "Copied for Codex"
        case .copied:
            CaptureCopy.copiedTitle
        case .permissionNeeded(let kind):
            switch kind {
            case .accessibility: "Accessibility needed"
            case .screenRecording: "Screen Recording needed"
            case .automation: "Automation needed"
            }
        case .codexNotFocused:
            "Paste in Codex when you’re ready"
        case .failed:
            CaptureCopy.failedTitle
        }
    }

    var userFacingDetail: String {
        switch self {
        case .ready:
            "Choose a mode, then capture."
        case .armed:
            "Press Esc to cancel."
        case .selectingArea:
            "Release to capture the selected area."
        case .capturing:
            "Freezing the selected area."
        case .pasteAttempted:
            "CueShot sent a Paste command. Confirm the image appears before sending your message."
        case .codexAppServerAccepted:
            "The image is copied. If it does not appear in Codex, drag the PNG preview."
        case .copied(let reason):
            reason.replacingOccurrences(of: "PNG copied. Press Cmd+V in Codex or drag the preview.", with: CaptureCopy.copiedDetail)
        case .permissionNeeded(let kind):
            kind.presentation.detail
        case .codexNotFocused:
            "The image is copied. Focus Codex and paste it there."
        case .failed(let reason):
            reason
        }
    }
}

extension CaptureRecord {
    var createdAtShortText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }

    var detailsSummary: String {
        "\(mode.userFacingTitle) · \(dimensions) · \(fileSize)"
    }
}
