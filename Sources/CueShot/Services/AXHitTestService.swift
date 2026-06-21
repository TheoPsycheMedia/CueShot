import AppKit
import ApplicationServices
import Foundation

struct AXHitTestService {
    func target(at point: CGPoint, mode: CaptureMode) -> CaptureTarget {
        switch mode {
        case .screen:
            return screenTarget(at: point)
        case .selection:
            return estimatedTarget(at: point, confidence: .estimated)
        case .area:
            return screenTarget(at: point)
        case .window:
            return windowTarget(at: point)
        case .element:
            return elementTarget(at: point)
        }
    }

    func areaTarget(from start: CGPoint, to end: CGPoint) -> CaptureTarget {
        let screenFrame = displayFrame(containing: start)
        let rawRect = CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
        let clamped = rawRect.standardized.intersection(screenFrame.standardized)
        let rect = clamped.isNull ? CGRect(origin: start, size: .zero) : clamped.integral
        let point = rect.isEmpty ? start : CGPoint(x: rect.midX, y: rect.midY)

        return CaptureTarget(
            point: point,
            screenFrame: screenFrame,
            rect: rect,
            sourceAppName: NSWorkspace.shared.frontmostApplication?.localizedName ?? "Manual Area",
            sourceBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            axRole: "ManualArea",
            axSubrole: nil,
            axTitle: nil,
            confidence: .manualArea
        )
    }

    private func elementTarget(at point: CGPoint) -> CaptureTarget {
        guard AXIsProcessTrusted() else {
            return estimatedTarget(at: point, confidence: .estimated)
        }

        let systemWideElement = AXUIElementCreateSystemWide()
        var rawElement: AXUIElement?
        let error = AXUIElementCopyElementAtPosition(systemWideElement, Float(point.x), Float(point.y), &rawElement)

        guard error == .success, let element = rawElement else {
            return estimatedTarget(at: point, confidence: .estimated)
        }

        let resolvedElement = bestElement(startingAt: element, point: point)
        let role = stringAttribute(kAXRoleAttribute, from: resolvedElement) ?? "AXElement"
        let subrole = stringAttribute(kAXSubroleAttribute, from: resolvedElement)
        let title = sanitizedTitle(for: resolvedElement, role: role, subrole: subrole)
        let screenFrame = displayFrame(containing: point)
        let rawBounds = bounds(for: resolvedElement)
        let fallbackBounds = fallbackWindowBounds(for: resolvedElement)
        let rect = captureRect(for: rawBounds ?? fallbackBounds ?? estimatedRect(around: point), screenFrame: screenFrame)
        let app = runningApplication(for: resolvedElement)
        let confidence = elementConfidence(rawBounds: rawBounds, fallbackBounds: fallbackBounds, role: role, rect: rect, screenFrame: screenFrame)

        return CaptureTarget(
            point: point,
            screenFrame: screenFrame,
            rect: rect.standardized,
            sourceAppName: app?.localizedName ?? "Unknown App",
            sourceBundleID: app?.bundleIdentifier,
            axRole: role,
            axSubrole: subrole,
            axTitle: title,
            confidence: confidence
        )
    }

    private func windowTarget(at point: CGPoint) -> CaptureTarget {
        guard AXIsProcessTrusted() else {
            return estimatedTarget(at: point, confidence: .windowFallback)
        }

        let systemWideElement = AXUIElementCreateSystemWide()
        var rawElement: AXUIElement?
        let error = AXUIElementCopyElementAtPosition(systemWideElement, Float(point.x), Float(point.y), &rawElement)

        guard error == .success, let element = rawElement else {
            return estimatedTarget(at: point, confidence: .windowFallback)
        }

        let rect = fallbackWindowBounds(for: element) ?? bounds(for: element) ?? estimatedRect(around: point)
        let app = runningApplication(for: element)

        return CaptureTarget(
            point: point,
            screenFrame: displayFrame(containing: point),
            rect: rect.standardized,
            sourceAppName: app?.localizedName ?? "Unknown App",
            sourceBundleID: app?.bundleIdentifier,
            axRole: "NSWindow",
            axSubrole: nil,
            axTitle: nil,
            confidence: .windowFallback
        )
    }

    private func screenTarget(at point: CGPoint) -> CaptureTarget {
        let screenFrame = displayFrame(containing: point)

        return CaptureTarget(
            point: point,
            screenFrame: screenFrame,
            rect: screenFrame,
            sourceAppName: "Display",
            sourceBundleID: nil,
            axRole: "Display",
            axSubrole: nil,
            axTitle: nil,
            confidence: .estimated
        )
    }

    private func estimatedTarget(at point: CGPoint, confidence: TargetConfidence) -> CaptureTarget {
        CaptureTarget(
            point: point,
            screenFrame: displayFrame(containing: point),
            rect: estimatedRect(around: point),
            sourceAppName: NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown App",
            sourceBundleID: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            axRole: "Estimated",
            axSubrole: nil,
            axTitle: nil,
            confidence: confidence
        )
    }

    private func stringAttribute(_ name: String, from element: AXUIElement) -> String? {
        var rawValue: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, name as CFString, &rawValue)
        guard error == .success else { return nil }
        return rawValue as? String
    }

    private func bestElement(startingAt element: AXUIElement, point: CGPoint) -> AXUIElement {
        var current: AXUIElement? = element
        var candidates: [(element: AXUIElement, score: CGFloat)] = []
        var depth: CGFloat = 0

        while let candidate = current, depth < 8 {
            if let rect = bounds(for: candidate), rect.contains(point), rect.width > 4, rect.height > 4 {
                let role = stringAttribute(kAXRoleAttribute, from: candidate) ?? "AXElement"
                let subrole = stringAttribute(kAXSubroleAttribute, from: candidate)
                let title = sanitizedTitle(for: candidate, role: role, subrole: subrole)
                candidates.append((candidate, score(for: role, title: title, rect: rect, depth: depth, point: point)))
            }

            current = elementAttribute(kAXParentAttribute, from: candidate)
            depth += 1
        }

        return candidates.max { $0.score < $1.score }?.element ?? element
    }

    private func score(for role: String, title: String?, rect: CGRect, depth: CGFloat, point: CGPoint) -> CGFloat {
        let area = rect.width * rect.height
        var score = roleWeight(role)

        if title?.isEmpty == false {
            score += 12
        }

        if area < 600 {
            score -= 24
        } else if area < 120_000 {
            score += 20
        } else if area > 700_000 {
            score -= 34
        }

        if rect.width < 18 || rect.height < 18 {
            score -= 30
        }

        let centerDistance = hypot(rect.midX - point.x, rect.midY - point.y)
        score -= min(centerDistance / 140, 14)
        score -= depth * 2.2
        return score
    }

    private func roleWeight(_ role: String) -> CGFloat {
        switch role {
        case "AXButton", "AXLink", "AXPopUpButton", "AXCheckBox", "AXRadioButton", "AXTextField", "AXSearchField", "AXComboBox", "AXMenuItem":
            120
        case "AXImage":
            82
        case "AXStaticText":
            72
        case "AXGroup", "AXCell", "AXRow", "AXWebArea", "AXScrollArea":
            58
        case "AXWindow":
            18
        default:
            46
        }
    }

    private func bounds(for element: AXUIElement) -> CGRect? {
        guard
            let position = pointAttribute(kAXPositionAttribute, from: element),
            let size = sizeAttribute(kAXSizeAttribute, from: element),
            size.width > 1,
            size.height > 1
        else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    private func captureRect(for rect: CGRect, screenFrame: CGRect) -> CGRect {
        let padded = rect.standardized.insetBy(dx: -3, dy: -3)
        let clamped = padded.intersection(screenFrame.standardized)
        guard !clamped.isNull, clamped.width > 1, clamped.height > 1 else {
            return rect.standardized
        }

        return clamped
    }

    private func elementConfidence(rawBounds: CGRect?, fallbackBounds: CGRect?, role: String, rect: CGRect, screenFrame: CGRect) -> TargetConfidence {
        guard rawBounds != nil else {
            return fallbackBounds == nil ? .estimated : .windowFallback
        }

        if isCoarseContainer(role: role, rect: rect, screenFrame: screenFrame) {
            return .adjusted
        }

        return .exact
    }

    private func isCoarseContainer(role: String, rect: CGRect, screenFrame: CGRect) -> Bool {
        let containerRoles: Set<String> = [
            "AXApplication",
            "AXBrowser",
            "AXGroup",
            "AXLayoutArea",
            "AXScrollArea",
            "AXSplitGroup",
            "AXTabGroup",
            "AXUnknown",
            "AXWebArea",
            "AXWindow"
        ]
        guard containerRoles.contains(role) else { return false }

        let screenArea = max(screenFrame.width * screenFrame.height, 1)
        let rectArea = max(rect.width * rect.height, 1)
        let coversMostWidth = rect.width >= screenFrame.width * 0.72
        let coversMostHeight = rect.height >= screenFrame.height * 0.72
        return rectArea / screenArea >= 0.34 || (coversMostWidth && coversMostHeight)
    }

    private func fallbackWindowBounds(for element: AXUIElement) -> CGRect? {
        var rawWindow: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, kAXWindowAttribute as CFString, &rawWindow)
        guard error == .success, let window = rawWindow else { return nil }
        return bounds(for: (window as! AXUIElement))
    }

    private func elementAttribute(_ name: String, from element: AXUIElement) -> AXUIElement? {
        var rawValue: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, name as CFString, &rawValue)
        guard error == .success, let value = rawValue else { return nil }
        return (value as! AXUIElement)
    }

    private func pointAttribute(_ name: String, from element: AXUIElement) -> CGPoint? {
        var rawValue: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, name as CFString, &rawValue)
        guard error == .success, let value = rawValue else { return nil }

        var point = CGPoint.zero
        guard AXValueGetValue((value as! AXValue), .cgPoint, &point) else {
            return nil
        }

        return point
    }

    private func sizeAttribute(_ name: String, from element: AXUIElement) -> CGSize? {
        var rawValue: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, name as CFString, &rawValue)
        guard error == .success, let value = rawValue else { return nil }

        var size = CGSize.zero
        guard AXValueGetValue((value as! AXValue), .cgSize, &size) else {
            return nil
        }

        return size
    }

    private func runningApplication(for element: AXUIElement) -> NSRunningApplication? {
        var pid = pid_t()
        guard AXUIElementGetPid(element, &pid) == .success else {
            return NSWorkspace.shared.frontmostApplication
        }

        return NSRunningApplication(processIdentifier: pid)
    }

    private func sanitizedTitle(for element: AXUIElement, role: String, subrole: String?) -> String? {
        guard subrole != "AXSecureTextField", role != "AXSecureTextField" else {
            return nil
        }

        return stringAttribute(kAXTitleAttribute, from: element)
            ?? stringAttribute(kAXDescriptionAttribute, from: element)
    }

    private func estimatedRect(around point: CGPoint) -> CGRect {
        CGRect(x: point.x - 130, y: point.y - 80, width: 260, height: 160)
    }

    private func displayFrame(containing point: CGPoint) -> CGRect {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &displays, &count)

        for display in displays {
            let bounds = CGDisplayBounds(display)
            if bounds.contains(point) {
                return bounds
            }
        }

        return CGDisplayBounds(CGMainDisplayID())
    }
}
