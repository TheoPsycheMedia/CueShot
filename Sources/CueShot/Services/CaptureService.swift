import AppKit
import Foundation
@preconcurrency import ScreenCaptureKit

private struct CapturePlan {
    let rect: CGRect
    let provider: CaptureProvider
}

private enum CaptureProvider {
    case screenCaptureKitFiltered(contentFilter: SCContentFilter, configuration: SCStreamConfiguration)
    case screenCaptureKitRect(CGRect)
    case legacyRect(CGRect)
}

struct CaptureCoordinateMapper {
    static func sourceRect(for captureRect: CGRect, in displayFrame: CGRect) -> CGRect {
        CGRect(
            x: captureRect.minX - displayFrame.minX,
            y: captureRect.minY - displayFrame.minY,
            width: captureRect.width,
            height: captureRect.height
        ).integral
    }

    static func outputSize(for captureRect: CGRect, displayScale: CGFloat) -> CGSize {
        let scale = max(displayScale, 1)
        return CGSize(
            width: max((captureRect.width * scale).rounded(.up), 1),
            height: max((captureRect.height * scale).rounded(.up), 1)
        )
    }
}

@available(macOS 14.0, *)
private struct ScreenCaptureKitPlanner {
    func makePlan(target: CaptureTarget, rect: CGRect) async -> CapturePlan? {
        do {
            let content = try await shareableContent()
            guard let display = matchingDisplay(in: content, for: target, rect: rect) else {
                return nil
            }

            let filter: SCContentFilter
            let excludedApplications = cueShotApplicationsToExclude(in: content, for: target)
            if excludedApplications.isEmpty {
                filter = SCContentFilter(display: display, excludingWindows: [])
            } else {
                filter = SCContentFilter(display: display, excludingApplications: excludedApplications, exceptingWindows: [])
            }

            let sourceRect = CaptureCoordinateMapper.sourceRect(for: rect, in: display.frame)
            let pixelSize = CaptureCoordinateMapper.outputSize(
                for: rect,
                displayScale: displayScale(for: display.displayID)
            )
            let configuration = SCStreamConfiguration()
            configuration.width = size_t(pixelSize.width)
            configuration.height = size_t(pixelSize.height)
            configuration.sourceRect = sourceRect
            configuration.showsCursor = false
            configuration.scalesToFit = false
            configuration.queueDepth = 1

            return CapturePlan(
                rect: rect,
                provider: .screenCaptureKitFiltered(contentFilter: filter, configuration: configuration)
            )
        } catch {
            return nil
        }
    }

    private func shareableContent() async throws -> SCShareableContent {
        try await withCheckedThrowingContinuation { continuation in
            SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { content, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let content {
                    continuation.resume(returning: content)
                } else {
                    continuation.resume(throwing: CueShotCaptureError.emptyImage)
                }
            }
        }
    }

    private func matchingDisplay(in content: SCShareableContent, for target: CaptureTarget, rect: CGRect) -> SCDisplay? {
        if let exactMatch = content.displays.first(where: { approximatelyEqual($0.frame, target.screenFrame) }) {
            return exactMatch
        }

        let bestIntersection = content.displays
            .map { display in
                (display, rect.intersection(display.frame).standardized)
            }
            .filter { !$0.1.isNull }
            .max { lhs, rhs in
                (lhs.1.width * lhs.1.height) < (rhs.1.width * rhs.1.height)
            }

        if let bestIntersection {
            return bestIntersection.0
        }

        return content.displays.first(where: { $0.frame.contains(target.point) })
    }

    private func cueShotApplicationsToExclude(in content: SCShareableContent, for target: CaptureTarget) -> [SCRunningApplication] {
        guard let cueShotBundleID = Bundle.main.bundleIdentifier else {
            return []
        }

        guard target.sourceBundleID != cueShotBundleID else {
            return []
        }

        return content.applications.filter { $0.bundleIdentifier == cueShotBundleID }
    }

    private func displayScale(for displayID: CGDirectDisplayID) -> CGFloat {
        guard
            let mode = CGDisplayCopyDisplayMode(displayID),
            CGDisplayBounds(displayID).width > 0
        else {
            return 1
        }

        return CGFloat(mode.pixelWidth) / CGDisplayBounds(displayID).width
    }

    private func approximatelyEqual(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat = 1) -> Bool {
        abs(lhs.minX - rhs.minX) <= tolerance &&
            abs(lhs.minY - rhs.minY) <= tolerance &&
            abs(lhs.width - rhs.width) <= tolerance &&
            abs(lhs.height - rhs.height) <= tolerance
    }
}

struct CaptureService {
    private let ocrService = OCRService()

    func capture(target: CaptureTarget, mode: CaptureMode) async throws -> CaptureResult {
        let rect = normalizedCaptureRect(for: target)
        let plan = await capturePlan(for: target, rect: rect)
        let image = try await captureImage(using: plan)
        let pngData = try encodePNG(image)
        let ocrText = try await recognizedText(for: image, mode: mode)
        let record = CaptureRecord(
            id: UUID(),
            createdAt: .now,
            mode: mode,
            confidence: target.confidence.rawValue,
            sourceAppName: target.sourceAppName,
            axRole: target.axRole,
            dimensions: "\(image.width) x \(image.height)",
            fileSize: ByteCountFormatter.string(fromByteCount: Int64(pngData.count), countStyle: .file),
            handoffStatus: "Prepared",
            pngRelativePath: nil,
            recognizedText: ocrText
        )

        return CaptureResult(record: record, pngData: pngData, image: image)
    }

    private func recognizedText(for image: CGImage, mode: CaptureMode) async throws -> String? {
        guard mode == .ocr else {
            return nil
        }

        return try await ocrService.recognizeText(in: image)
    }

    private func capturePlan(for target: CaptureTarget, rect: CGRect) async -> CapturePlan {
        if #available(macOS 14.0, *),
           let filteredPlan = await ScreenCaptureKitPlanner().makePlan(target: target, rect: rect) {
            return filteredPlan
        }

        if #available(macOS 15.2, *) {
            return CapturePlan(rect: rect, provider: .screenCaptureKitRect(rect))
        }

        return CapturePlan(rect: rect, provider: .legacyRect(rect))
    }

    private func normalizedCaptureRect(for target: CaptureTarget) -> CGRect {
        let clamped = target.rect.standardized.intersection(target.screenFrame.standardized)
        guard !clamped.isNull, clamped.width > 1, clamped.height > 1 else {
            return target.screenFrame.standardized.integral
        }

        return clamped.integral
    }

    private func captureImage(using plan: CapturePlan) async throws -> CGImage {
        switch plan.provider {
        case .screenCaptureKitFiltered(let contentFilter, let configuration):
            guard #available(macOS 14.0, *) else {
                return try await captureImage(using: CapturePlan(rect: plan.rect, provider: .legacyRect(plan.rect)))
            }

            return try await withCheckedThrowingContinuation { continuation in
                SCScreenshotManager.captureImage(contentFilter: contentFilter, configuration: configuration) { image, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let image {
                        continuation.resume(returning: image)
                    } else {
                        continuation.resume(throwing: CueShotCaptureError.emptyImage)
                    }
                }
            }
        case .screenCaptureKitRect(let rect):
            guard #available(macOS 15.2, *) else {
                return try await captureImage(using: CapturePlan(rect: rect, provider: .legacyRect(rect)))
            }

            return try await withCheckedThrowingContinuation { continuation in
                SCScreenshotManager.captureImage(in: rect) { image, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let image {
                        continuation.resume(returning: image)
                    } else {
                        continuation.resume(throwing: CueShotCaptureError.emptyImage)
                    }
                }
            }
        case .legacyRect(let rect):
            guard let image = CGWindowListCreateImage(rect, .optionOnScreenOnly, kCGNullWindowID, [.bestResolution]) else {
                throw CueShotCaptureError.emptyImage
            }

            return image
        }
    }

    private func encodePNG(_ image: CGImage) throws -> Data {
        let representation = NSBitmapImageRep(cgImage: image)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            throw CueShotCaptureError.pngEncodingFailed
        }

        return data
    }
}

enum CueShotCaptureError: LocalizedError {
    case emptyImage
    case pngEncodingFailed

    var errorDescription: String? {
        switch self {
        case .emptyImage:
            "CueShot could not capture pixels for the selected target."
        case .pngEncodingFailed:
            "CueShot captured the target but could not encode the PNG."
        }
    }
}

struct CaptureResult {
    let record: CaptureRecord
    let pngData: Data
    let image: CGImage?

    init(record: CaptureRecord, pngData: Data, image: CGImage? = nil) {
        self.record = record
        self.pngData = pngData
        self.image = image
    }
}
