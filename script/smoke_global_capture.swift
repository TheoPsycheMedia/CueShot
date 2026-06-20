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
    AXUIElementSetMessagingTimeout(element, 0.25)
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
    guard depth < 10 else { return nil }

    AXUIElementSetMessagingTimeout(element, 0.25)
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

guard UserDefaults(suiteName: "com.edgariraheta.CueShot")?.bool(forKey: "enableSmokeAutomation") == true else {
    fail("Smoke automation is disabled. Enable it with: defaults write com.edgariraheta.CueShot enableSmokeAutomation -bool true, then relaunch CueShot.")
}

let before = manifestRecords().count
let cueShotApp = NSWorkspace.shared.runningApplications.first {
    $0.localizedName == "CueShot" || $0.bundleIdentifier == "com.edgariraheta.CueShot"
}

guard let cueShotApp else {
    fail("CueShot is not running.")
}

let axApp = AXUIElementCreateApplication(cueShotApp.processIdentifier)
AXUIElementSetMessagingTimeout(axApp, 0.25)
func loadWindows() -> [AXUIElement] {
    let values = (attribute(kAXWindowsAttribute, from: axApp) as? [AXUIElement]) ?? []
    values.forEach { AXUIElementSetMessagingTimeout($0, 0.25) }
    return values
}

var windows = loadWindows()

func captureControlWindows() -> [AXUIElement] {
    windows.filter { window in
        guard let size = axValue(attribute(kAXSizeAttribute, from: window), type: .cgSize, as: CGSize.self) else {
            return false
        }

        return size.width >= 320 && size.width <= 560 && size.height >= 80 && size.height <= 220
    }
}

func postShowCaptureControlShortcut() {
    cueShotApp.activate(options: [.activateIgnoringOtherApps])
    usleep(200_000)

    let source = CGEventSource(stateID: .hidSystemState)
    for keyDown in [true, false] {
        let event = CGEvent(keyboardEventSource: source, virtualKey: 18, keyDown: keyDown)
        event?.flags = [.maskCommand, .maskShift]
        event?.post(tap: .cghidEventTap)
        usleep(40_000)
    }
}

func findFloatingButton(containing needles: [String]) -> AXUIElement? {
    let searchWindows = captureControlWindows()
    for needle in needles {
        if let button = searchWindows.compactMap({ findButton(in: $0, containing: needle) }).first {
            return button
        }
    }

    return nil
}

func ensureCaptureControlVisible(containing needles: [String]) -> AXUIElement? {
    if let button = findFloatingButton(containing: needles) {
        return button
    }

    postShowCaptureControlShortcut()
    let deadline = Date().addingTimeInterval(3)
    while Date() < deadline {
        windows = loadWindows()
        if let button = findFloatingButton(containing: needles) {
            return button
        }

        usleep(120_000)
    }

    return nil
}

func requestCaptureControl() {
    DistributedNotificationCenter.default().postNotificationName(
        Notification.Name("com.edgariraheta.CueShot.showCaptureControl"),
        object: nil,
        userInfo: nil,
        deliverImmediately: true
    )
}

func selectMode(_ mode: String) {
    DistributedNotificationCenter.default().postNotificationName(
        Notification.Name("com.edgariraheta.CueShot.selectCaptureMode"),
        object: nil,
        userInfo: ["mode": mode],
        deliverImmediately: true
    )
}

func armCapture() {
    DistributedNotificationCenter.default().postNotificationName(
        Notification.Name("com.edgariraheta.CueShot.armCapture"),
        object: nil,
        userInfo: nil,
        deliverImmediately: true
    )
}

func cgFloat(_ value: Any?) -> CGFloat? {
    if let value = value as? CGFloat {
        return value
    }
    if let value = value as? NSNumber {
        return CGFloat(truncating: value)
    }
    return nil
}

func captureControlBounds() -> CGRect? {
    let windows = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
    for window in windows {
        guard
            (window[kCGWindowOwnerName as String] as? String) == "CueShot",
            (window[kCGWindowName as String] as? String) == "CueShot Capture Control",
            (window[kCGWindowIsOnscreen as String] as? Bool) == true,
            let rawBounds = window[kCGWindowBounds as String] as? [String: Any],
            let x = cgFloat(rawBounds["X"]),
            let y = cgFloat(rawBounds["Y"]),
            let width = cgFloat(rawBounds["Width"]),
            let height = cgFloat(rawBounds["Height"])
        else {
            continue
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }

    return nil
}

func ensureCaptureControlBounds() -> CGRect? {
    requestCaptureControl()
    let deadline = Date().addingTimeInterval(3)
    while Date() < deadline {
        if let bounds = captureControlBounds() {
            return bounds
        }

        usleep(120_000)
    }

    return nil
}

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

func postMouse(_ type: CGEventType, at point: CGPoint) {
    let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left)
    event?.flags = []
    event?.post(tap: .cghidEventTap)
}

func click(_ point: CGPoint) {
    postMouse(.leftMouseDown, at: point)
    usleep(45_000)
    postMouse(.leftMouseUp, at: point)
}

func postClick(_ type: CGEventType) {
    postMouse(type, at: clickPoint)
}

requestCaptureControl()
selectMode("element")
usleep(180_000)
armCapture()

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
