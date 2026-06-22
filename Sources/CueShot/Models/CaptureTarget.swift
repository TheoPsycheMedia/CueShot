import CoreGraphics
import Foundation

enum TargetConfidence: String, Codable, Equatable {
    case exact = "Exact"
    case adjusted = "Adjusted"
    case estimated = "Estimated"
    case windowFallback = "Window"
    case manualArea = "Area"
}

struct CaptureTarget: Equatable {
    let point: CGPoint
    let screenFrame: CGRect
    let rect: CGRect
    let sourceAppName: String
    let sourceBundleID: String?
    let axRole: String
    let axSubrole: String?
    let axTitle: String?
    let confidence: TargetConfidence

    var dimensionsText: String {
        "\(Int(rect.width.rounded())) x \(Int(rect.height.rounded()))"
    }

    var metadataLabel: String {
        "\(sourceAppName) - \(axRole)"
    }
}

enum GestureEvent: Equatable {
    case armed(point: CGPoint)
    case moved(point: CGPoint)
    case resize(point: CGPoint, deltaX: CGFloat, deltaY: CGFloat, axis: CaptureResizeAxis)
    case areaStarted(start: CGPoint, current: CGPoint)
    case areaChanged(start: CGPoint, current: CGPoint)
    case areaFinished(start: CGPoint, end: CGPoint)
    case cancelled
    case click(point: CGPoint)
    case tripleClick(point: CGPoint)
}

enum CaptureResizeAxis: Equatable, Sendable {
    case both
    case width
    case height
}

enum CaptureResizeModifier: String, CaseIterable, Identifiable, Codable, Equatable, Sendable {
    case shift
    case option
    case control
    case command

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shift: "Shift"
        case .option: "Option"
        case .control: "Control"
        case .command: "Command"
        }
    }

    var menuTitle: String {
        switch self {
        case .shift: "Shift"
        case .option: "Option"
        case .control: "Control"
        case .command: "Command"
        }
    }
}

struct CaptureResizeBindings: Equatable, Sendable {
    var widthModifier: CaptureResizeModifier = .shift
    var heightModifier: CaptureResizeModifier = .option

    func axis(for activeModifiers: Set<CaptureResizeModifier>) -> CaptureResizeAxis {
        let widthActive = activeModifiers.contains(widthModifier)
        let heightActive = activeModifiers.contains(heightModifier)

        if widthActive, !heightActive {
            return .width
        }
        if heightActive, !widthActive {
            return .height
        }
        return .both
    }
}

struct PrecisionSelectionState: Equatable {
    let baseTarget: CaptureTarget
    let anchorPoint: CGPoint
    let adjustedSize: CGSize
    let activeAxis: CaptureResizeAxis

    func moving(to point: CGPoint, baseTarget: CaptureTarget) -> PrecisionSelectionState {
        PrecisionSelectionState(
            baseTarget: baseTarget,
            anchorPoint: point,
            adjustedSize: adjustedSize,
            activeAxis: activeAxis
        )
    }

    func updating(size: CGSize, axis: CaptureResizeAxis) -> PrecisionSelectionState {
        PrecisionSelectionState(
            baseTarget: baseTarget,
            anchorPoint: anchorPoint,
            adjustedSize: size,
            activeAxis: axis
        )
    }
}
