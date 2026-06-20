import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

struct SmokeFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("smoke=failed reason=\"\(message)\"\n".utf8))
    exit(1)
}

let fileManager = FileManager.default
let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
let historyURL = supportURL
    .appendingPathComponent("CueShot", isDirectory: true)
    .appendingPathComponent("History", isDirectory: true)
let manifestURL = historyURL.appendingPathComponent("captures.json")

func manifestRecords() -> [[String: Any]] {
    guard let data = try? Data(contentsOf: manifestURL),
          let records = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
        return []
    }

    return records
}

func axValue<T>(_ value: CFTypeRef?, type: AXValueType, as _: T.Type) -> T? {
    guard let value else { return nil }

    if T.self == CGPoint.self {
        var point = CGPoint.zero
        guard AXValueGetValue((value as! AXValue), type, &point) else { return nil }
        return point as? T
    }

    if T.self == CGSize.self {
        var size = CGSize.zero
        guard AXValueGetValue((value as! AXValue), type, &size) else { return nil }
        return size as? T
    }

    fatalError("Unsupported AX value type")
}

func attribute(_ name: String, from element: AXUIElement) -> CFTypeRef? {
    var rawValue: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &rawValue) == .success else {
        return nil
    }

    return rawValue
}

func stringAttribute(_ name: String, from element: AXUIElement) -> String? {
    attribute(name, from: element) as? String
}

func children(of element: AXUIElement) -> [AXUIElement] {
    (attribute(kAXChildrenAttribute, from: element) as? [AXUIElement]) ?? []
}

func findButton(in element: AXUIElement, containing needle: String, depth: Int = 0) -> AXUIElement? {
    guard depth < 12 else { return nil }

    let role = stringAttribute(kAXRoleAttribute, from: element)
    let strings = [
        stringAttribute(kAXTitleAttribute, from: element),
        stringAttribute(kAXDescriptionAttribute, from: element),
        stringAttribute("AXIdentifier", from: element)
    ]
    .compactMap { $0 }
    .joined(separator: " ")

    if role == (kAXButtonRole as String), strings.localizedCaseInsensitiveContains(needle) {
        return element
    }

    for child in children(of: element) {
        if let match = findButton(in: child, containing: needle, depth: depth + 1) {
            return match
        }
    }

    return nil
}

guard AXIsProcessTrusted() else {
    fail("Accessibility is not trusted for the smoke runner.")
}

let before = manifestRecords().count
let cueShotApp = NSWorkspace.shared.runningApplications.first {
    $0.localizedName == "CueShot" || $0.bundleIdentifier == "com.edgariraheta.CueShot"
}

guard let cueShotApp else {
    fail("CueShot is not running.")
}

let axApp = AXUIElementCreateApplication(cueShotApp.processIdentifier)
let windows = (attribute(kAXWindowsAttribute, from: axApp) as? [AXUIElement]) ?? []
let resolvedWindow = windows.compactMap { window -> (CGPoint, CGSize)? in
    guard
        let position = axValue(attribute(kAXPositionAttribute, from: window), type: .cgPoint, as: CGPoint.self),
        let size = axValue(attribute(kAXSizeAttribute, from: window), type: .cgSize, as: CGSize.self),
        size.width > 300,
        size.height > 160
    else {
        return nil
    }

    return (position, size)
}.first

let clickPoint: CGPoint
if let (position, size) = resolvedWindow {
    clickPoint = CGPoint(
        x: position.x + min(max(size.width * 0.50, 180), size.width - 80),
        y: position.y + min(max(size.height * 0.50, 140), size.height - 80)
    )
} else {
    let frame = CGDisplayBounds(CGMainDisplayID())
    clickPoint = CGPoint(x: frame.midX, y: frame.midY)
}

let source = CGEventSource(stateID: .hidSystemState)

func postClick(_ type: CGEventType) {
    let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: clickPoint, mouseButton: .left)
    event?.flags = []
    event?.post(tap: .cghidEventTap)
}

let captureButton =
    findButton(in: axApp, containing: "CueShot Capture")
    ?? windows.compactMap { findButton(in: $0, containing: "arm") }.first
    ?? findButton(in: axApp, containing: "arm")
    ?? windows.compactMap { findButton(in: $0, containing: "capture") }.first
    ?? findButton(in: axApp, containing: "capture")
guard let captureButton else {
    fail("Could not find the CueShot floating Arm button through Accessibility.")
}

let pressResult = AXUIElementPerformAction(captureButton, kAXPressAction as CFString)
guard pressResult == .success else {
    fail("Could not press the floating Arm button. AX result: \(pressResult.rawValue)")
}

usleep(450_000)
postClick(.leftMouseDown)
usleep(45_000)
postClick(.leftMouseUp)

let deadline = Date().addingTimeInterval(6)
while Date() < deadline {
    let records = manifestRecords()
    if records.count > before,
       let path = records.first?["pngRelativePath"] as? String {
        let pngURL = historyURL.appendingPathComponent(path)
        if fileManager.fileExists(atPath: pngURL.path) {
            let attributes = try fileManager.attributesOfItem(atPath: pngURL.path)
            let size = attributes[.size] as? NSNumber
            print("smoke=passed recordsBefore=\(before) recordsAfter=\(records.count) png=\(pngURL.path) bytes=\(size?.intValue ?? 0)")
            exit(0)
        }
    }

    usleep(200_000)
}

fail("CueShot did not create a persisted PNG capture after the floating Arm flow. Check macOS Privacy grants for the CueShot app bundle.")
