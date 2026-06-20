import CoreGraphics
import Foundation

enum TargetConfidence: String, Codable, Equatable {
    case exact = "Exact"
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
    case areaStarted(start: CGPoint, current: CGPoint)
    case areaChanged(start: CGPoint, current: CGPoint)
    case areaFinished(start: CGPoint, end: CGPoint)
    case cancelled
    case click(point: CGPoint)
    case tripleClick(point: CGPoint)
}

struct CaptureResult {
    let record: CaptureRecord
    let pngData: Data
}
