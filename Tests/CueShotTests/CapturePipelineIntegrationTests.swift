import AppKit
import ApplicationServices
import CoreGraphics
import XCTest
@testable import CueShot

final class CapturePipelineIntegrationTests: XCTestCase {
    func testScreenCapturePersistsPNGAndCopiesToPasteboard() async throws {
        guard CGPreflightScreenCaptureAccess() else {
            throw XCTSkip("Screen Recording is not granted to the test host.")
        }

        let screenFrame = CGDisplayBounds(CGMainDisplayID())
        let rect = CGRect(x: screenFrame.midX - 40, y: screenFrame.midY - 30, width: 80, height: 60).integral
        let target = CaptureTarget(
            point: CGPoint(x: rect.midX, y: rect.midY),
            screenFrame: screenFrame,
            rect: rect,
            sourceAppName: "CueShotTests",
            sourceBundleID: nil,
            axRole: "IntegrationRect",
            axSubrole: nil,
            axTitle: nil,
            confidence: .manualArea
        )

        let result = try await CaptureService().capture(target: target, mode: .area)
        XCTAssertGreaterThan(result.pngData.count, 100)
        XCTAssertTrue(result.pngData.starts(with: [0x89, 0x50, 0x4E, 0x47]))
        XCTAssertTrue(result.record.dimensions.contains("x"))

        let root = temporarySupportRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = CaptureHistoryStore(applicationSupportURL: root)
        let persisted = try store.persist(result: result)
        XCTAssertNotNil(persisted.pngRelativePath)
        XCTAssertEqual(store.load().first?.id, persisted.id)
        XCTAssertEqual(store.pngData(for: persisted), result.pngData)

        let copiedRecord = persisted.withHandoffStatus("Copied")
        try store.update(copiedRecord)
        XCTAssertEqual(store.load().first?.handoffStatus, "Copied")

        CodexHandoffService().copyToPasteboard(pngData: result.pngData)
        XCTAssertEqual(NSPasteboard.general.data(forType: .png), result.pngData)
    }

    func testHistoryStorePrunesToThirtyCaptures() throws {
        let root = temporarySupportRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let store = CaptureHistoryStore(applicationSupportURL: root)
        let pngData = minimalPNGData()

        for index in 0..<34 {
            let record = CaptureRecord(
                id: UUID(),
                createdAt: .now.addingTimeInterval(TimeInterval(index)),
                mode: .area,
                confidence: TargetConfidence.manualArea.rawValue,
                sourceAppName: "CueShotTests",
                axRole: "IntegrationRect",
                dimensions: "1 x 1",
                fileSize: "\(pngData.count) B",
                handoffStatus: "Prepared",
                pngRelativePath: nil
            )
            _ = try store.persist(result: CaptureResult(record: record, pngData: pngData))
        }

        XCTAssertEqual(store.load().count, 30)
    }

    private func temporarySupportRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("CueShotTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func minimalPNGData() -> Data {
        let image = NSImage(size: NSSize(width: 1, height: 1))
        image.lockFocus()
        NSColor.black.setFill()
        NSRect(x: 0, y: 0, width: 1, height: 1).fill()
        image.unlockFocus()

        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let png = bitmap.representation(using: .png, properties: [:])
        else {
            XCTFail("Could not generate minimal PNG fixture.")
            return Data()
        }

        return png
    }
}
