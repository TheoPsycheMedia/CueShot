import Foundation
import SwiftUI

enum CueShotCommand: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case showCaptureControl
    case toggleCaptureControl
    case armCapture
    case cancelCapture
    case copyLastPNG
    case selectElementMode
    case selectSelectionMode
    case selectWindowMode
    case selectAreaMode
    case selectScreenMode
    case selectOCRMode
    case openSettings
    case showOnboarding

    var id: String { rawValue }

    var title: String {
        switch self {
        case .showCaptureControl: "Show Capture Control"
        case .toggleCaptureControl: "Toggle Floating Control"
        case .armCapture: "Arm Current Capture"
        case .cancelCapture: "Cancel Capture"
        case .copyLastPNG: "Copy Last PNG"
        case .selectElementMode: "Use Element Capture"
        case .selectSelectionMode: "Use Selection Capture"
        case .selectWindowMode: "Use Window Capture"
        case .selectAreaMode: "Use Area Capture"
        case .selectScreenMode: "Use Screen Capture"
        case .selectOCRMode: "Use OCR Capture"
        case .openSettings: "Open Settings"
        case .showOnboarding: "Show Onboarding"
        }
    }

    var detail: String {
        switch self {
        case .showCaptureControl: "Bring back the floating capture control."
        case .toggleCaptureControl: "Show or hide the floating control."
        case .armCapture: "Ready the current capture type from the floating control."
        case .cancelCapture: "Stop listening and remove the capture outline."
        case .copyLastPNG: "Copy the most recent CueShot capture."
        case .selectElementMode: "Capture the exact Accessibility element."
        case .selectSelectionMode: "Capture an estimated region around the click."
        case .selectWindowMode: "Capture the window under the cursor."
        case .selectAreaMode: "Draw a manual rectangle."
        case .selectScreenMode: "Capture the display you click."
        case .selectOCRMode: "Capture and recognize text from an estimated region around the click."
        case .openSettings: "Open CueShot settings."
        case .showOnboarding: "Show the setup walkthrough again."
        }
    }

    var symbol: String {
        switch self {
        case .showCaptureControl: "scope"
        case .toggleCaptureControl: "eye"
        case .armCapture: "smallcircle.filled.circle"
        case .cancelCapture: "xmark"
        case .copyLastPNG: "doc.on.doc"
        case .selectElementMode: "scope"
        case .selectSelectionMode: "cursorarrow.rays"
        case .selectWindowMode: "macwindow"
        case .selectAreaMode: "selection.pin.in.out"
        case .selectScreenMode: "display"
        case .selectOCRMode: "text.viewfinder"
        case .openSettings: "gearshape"
        case .showOnboarding: "sparkles"
        }
    }

    var groupTitle: String {
        switch self {
        case .showCaptureControl, .toggleCaptureControl, .armCapture, .cancelCapture, .copyLastPNG:
            "Capture"
        case .selectElementMode, .selectSelectionMode, .selectWindowMode, .selectAreaMode, .selectScreenMode:
            "Capture Type"
        case .selectOCRMode:
            "Capture Type"
        case .openSettings, .showOnboarding:
            "App"
        }
    }

    var defaultShortcut: CueShotShortcut {
        switch self {
        case .showCaptureControl:
            CueShotShortcut(key: .one, modifiers: [.command, .shift])
        case .toggleCaptureControl:
            CueShotShortcut(key: .b, modifiers: [.command, .shift])
        case .armCapture:
            CueShotShortcut(key: .a, modifiers: [.command, .shift])
        case .cancelCapture:
            CueShotShortcut(key: .escape, modifiers: [])
        case .copyLastPNG:
            CueShotShortcut(key: .c, modifiers: [.command, .shift])
        case .selectElementMode:
            CueShotShortcut(key: .one, modifiers: [.command, .option])
        case .selectSelectionMode:
            CueShotShortcut(key: .two, modifiers: [.command, .option])
        case .selectWindowMode:
            CueShotShortcut(key: .three, modifiers: [.command, .option])
        case .selectAreaMode:
            CueShotShortcut(key: .four, modifiers: [.command, .option])
        case .selectScreenMode:
            CueShotShortcut(key: .five, modifiers: [.command, .option])
        case .selectOCRMode:
            CueShotShortcut(key: .six, modifiers: [.command, .option])
        case .openSettings:
            CueShotShortcut(key: .comma, modifiers: [.command])
        case .showOnboarding:
            CueShotShortcut(key: .slash, modifiers: [.command, .shift])
        }
    }

    static var commandCenterOrder: [CueShotCommand] {
        [
            .showCaptureControl,
            .toggleCaptureControl,
            .armCapture,
            .cancelCapture,
            .copyLastPNG,
            .selectElementMode,
            .selectSelectionMode,
            .selectWindowMode,
            .selectAreaMode,
            .selectScreenMode,
            .selectOCRMode,
            .openSettings,
            .showOnboarding
        ]
    }

    static var defaultShortcuts: [CueShotCommand: CueShotShortcut] {
        Dictionary(uniqueKeysWithValues: allCases.map { ($0, $0.defaultShortcut) })
    }
}

struct CueShotShortcut: Codable, Equatable, Sendable {
    var key: CueShortcutKey?
    var modifiers: Set<CueShortcutModifier>

    init(key: CueShortcutKey?, modifiers: Set<CueShortcutModifier>) {
        self.key = key
        self.modifiers = modifiers
    }

    static let unassigned = CueShotShortcut(key: nil, modifiers: [])

    var isAssigned: Bool {
        key != nil
    }

    var eventModifiers: EventModifiers {
        var eventModifiers: EventModifiers = []
        if modifiers.contains(.command) {
            eventModifiers.insert(.command)
        }
        if modifiers.contains(.shift) {
            eventModifiers.insert(.shift)
        }
        if modifiers.contains(.option) {
            eventModifiers.insert(.option)
        }
        if modifiers.contains(.control) {
            eventModifiers.insert(.control)
        }
        return eventModifiers
    }

    var displayText: String {
        guard let key else {
            return "Unassigned"
        }
        return "\(modifierGlyphs)\(key.displayTitle)"
    }

    var accessibilityText: String {
        guard let key else {
            return "Unassigned"
        }
        let modifierNames = CueShortcutModifier.displayOrder
            .filter { modifiers.contains($0) }
            .map(\.title)
            .joined(separator: " ")
        return modifierNames.isEmpty ? key.accessibilityTitle : "\(modifierNames) \(key.accessibilityTitle)"
    }

    private var modifierGlyphs: String {
        CueShortcutModifier.displayOrder
            .filter { modifiers.contains($0) }
            .map(\.glyph)
            .joined()
    }
}

enum CueShortcutModifier: String, CaseIterable, Codable, Hashable, Sendable {
    case control
    case option
    case shift
    case command

    var title: String {
        switch self {
        case .control: "Control"
        case .option: "Option"
        case .shift: "Shift"
        case .command: "Command"
        }
    }

    var glyph: String {
        switch self {
        case .control: "⌃"
        case .option: "⌥"
        case .shift: "⇧"
        case .command: "⌘"
        }
    }

    static let displayOrder: [CueShortcutModifier] = [.control, .option, .shift, .command]
}

enum CueShortcutModifierPreset: String, CaseIterable, Identifiable, Sendable {
    case none
    case command
    case shift
    case option
    case control
    case shiftCommand
    case optionCommand
    case controlCommand
    case shiftOption
    case shiftControl
    case optionControl
    case shiftOptionCommand
    case shiftControlCommand
    case optionControlCommand
    case shiftOptionControl
    case shiftOptionControlCommand

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "None"
        case .command: "⌘"
        case .shift: "⇧"
        case .option: "⌥"
        case .control: "⌃"
        case .shiftCommand: "⇧⌘"
        case .optionCommand: "⌥⌘"
        case .controlCommand: "⌃⌘"
        case .shiftOption: "⇧⌥"
        case .shiftControl: "⇧⌃"
        case .optionControl: "⌥⌃"
        case .shiftOptionCommand: "⇧⌥⌘"
        case .shiftControlCommand: "⇧⌃⌘"
        case .optionControlCommand: "⌥⌃⌘"
        case .shiftOptionControl: "⇧⌥⌃"
        case .shiftOptionControlCommand: "⇧⌥⌃⌘"
        }
    }

    var modifiers: Set<CueShortcutModifier> {
        switch self {
        case .none: []
        case .command: [.command]
        case .shift: [.shift]
        case .option: [.option]
        case .control: [.control]
        case .shiftCommand: [.shift, .command]
        case .optionCommand: [.option, .command]
        case .controlCommand: [.control, .command]
        case .shiftOption: [.shift, .option]
        case .shiftControl: [.shift, .control]
        case .optionControl: [.option, .control]
        case .shiftOptionCommand: [.shift, .option, .command]
        case .shiftControlCommand: [.shift, .control, .command]
        case .optionControlCommand: [.option, .control, .command]
        case .shiftOptionControl: [.shift, .option, .control]
        case .shiftOptionControlCommand: [.shift, .option, .control, .command]
        }
    }

    static func matching(_ modifiers: Set<CueShortcutModifier>) -> CueShortcutModifierPreset {
        allCases.first { $0.modifiers == modifiers } ?? .none
    }
}

enum CueShortcutKey: String, CaseIterable, Identifiable, Codable, Sendable {
    case escape = "Esc"
    case one = "1"
    case two = "2"
    case three = "3"
    case four = "4"
    case five = "5"
    case six = "6"
    case seven = "7"
    case eight = "8"
    case nine = "9"
    case zero = "0"
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"
    case e = "E"
    case f = "F"
    case g = "G"
    case h = "H"
    case i = "I"
    case j = "J"
    case k = "K"
    case l = "L"
    case m = "M"
    case n = "N"
    case o = "O"
    case p = "P"
    case q = "Q"
    case r = "R"
    case s = "S"
    case t = "T"
    case u = "U"
    case v = "V"
    case w = "W"
    case x = "X"
    case y = "Y"
    case z = "Z"
    case comma = ","
    case period = "."
    case slash = "/"
    case semicolon = ";"
    case quote = "'"
    case leftBracket = "["
    case rightBracket = "]"
    case minus = "-"
    case equal = "="
    case space = "Space"

    var id: String { rawValue }

    var displayTitle: String { rawValue }

    var accessibilityTitle: String {
        switch self {
        case .escape: "Escape"
        case .comma: "Comma"
        case .period: "Period"
        case .slash: "Slash"
        case .semicolon: "Semicolon"
        case .quote: "Quote"
        case .leftBracket: "Left Bracket"
        case .rightBracket: "Right Bracket"
        case .minus: "Minus"
        case .equal: "Equal"
        case .space: "Space"
        default: rawValue
        }
    }

    var keyEquivalent: KeyEquivalent {
        switch self {
        case .escape:
            .escape
        case .space:
            KeyEquivalent(Character(" "))
        case .comma:
            ","
        case .period:
            "."
        case .slash:
            "/"
        case .semicolon:
            ";"
        case .quote:
            "'"
        case .leftBracket:
            "["
        case .rightBracket:
            "]"
        case .minus:
            "-"
        case .equal:
            "="
        default:
            KeyEquivalent(Character(rawValue.lowercased()))
        }
    }
}
