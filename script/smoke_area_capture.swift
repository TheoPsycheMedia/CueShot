import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("areaSmoke=failed reason=\"\(message)\"\n".utf8))
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

let frame = CGDisplayBounds(CGMainDisplayID())
let start = CGPoint(x: frame.midX - 180, y: frame.midY - 120)
let end = CGPoint(x: frame.midX + 180, y: frame.midY + 120)
let source = CGEventSource(stateID: .hidSystemState)

func postMouse(_ type: CGEventType, at point: CGPoint) {
    let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left)
    event?.flags = []
    event?.post(tap: .cghidEventTap)
}

usleep(450_000)
postMouse(.leftMouseDown, at: start)
usleep(35_000)
postMouse(.leftMouseDragged, at: CGPoint(x: frame.midX - 60, y: frame.midY - 40))
usleep(35_000)
postMouse(.leftMouseDragged, at: CGPoint(x: frame.midX + 80, y: frame.midY + 60))
usleep(35_000)
postMouse(.leftMouseDragged, at: end)
usleep(35_000)
postMouse(.leftMouseUp, at: end)

let deadline = Date().addingTimeInterval(6)
while Date() < deadline {
    let records = manifestRecords()
    if records.count > before,
       let first = records.first,
       let path = first["pngRelativePath"] as? String {
        let pngURL = historyURL.appendingPathComponent(path)
        if fileManager.fileExists(atPath: pngURL.path) {
            let attributes = try fileManager.attributesOfItem(atPath: pngURL.path)
            let size = attributes[.size] as? NSNumber
            let mode = first["mode"] as? String ?? "unknown"
            guard mode == "area" else {
                fail("Expected latest capture mode=area, got \(mode).")
            }
            print("areaSmoke=passed recordsBefore=\(before) recordsAfter=\(records.count) png=\(pngURL.path) bytes=\(size?.intValue ?? 0)")
            exit(0)
        }
    }

    usleep(200_000)
}

fail("CueShot did not create a persisted Area PNG after drag capture.")
