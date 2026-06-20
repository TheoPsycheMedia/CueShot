import AppKit
import Foundation
import ScreenCaptureKit

struct CaptureService {
    func capture(target: CaptureTarget, mode: CaptureMode) async throws -> CaptureResult {
        let rect = normalizedCaptureRect(for: target)
        let image = try await captureImage(in: rect)
        let pngData = try encodePNG(image)
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
            pngRelativePath: nil
        )

        return CaptureResult(record: record, pngData: pngData)
    }

    private func normalizedCaptureRect(for target: CaptureTarget) -> CGRect {
        let clamped = target.rect.standardized.intersection(target.screenFrame.standardized)
        guard !clamped.isNull, clamped.width > 1, clamped.height > 1 else {
            return target.screenFrame.standardized.integral
        }

        return clamped.integral
    }

    private func captureImage(in rect: CGRect) async throws -> CGImage {
        if #available(macOS 15.2, *) {
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
        }

        guard let image = CGWindowListCreateImage(rect, .optionOnScreenOnly, kCGNullWindowID, [.bestResolution]) else {
            throw CueShotCaptureError.emptyImage
        }

        return image
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
