import CoreGraphics
import XCTest
@testable import CueShot

final class TripleClickDetectorTests: XCTestCase {
    func testRecognizesThreeCommandClicksWithinThreshold() {
        var detector = TripleClickDetector()
        let point = CGPoint(x: 120, y: 80)

        XCTAssertFalse(detector.registerClick(point: point, timestamp: 1.00, commandDown: true))
        XCTAssertFalse(detector.registerClick(point: CGPoint(x: 123, y: 83), timestamp: 1.22, commandDown: true))
        XCTAssertTrue(detector.registerClick(point: CGPoint(x: 125, y: 82), timestamp: 1.50, commandDown: true))
    }

    func testRejectsClicksOutsideRadius() {
        var detector = TripleClickDetector()

        XCTAssertFalse(detector.registerClick(point: CGPoint(x: 10, y: 10), timestamp: 1.00, commandDown: true))
        XCTAssertFalse(detector.registerClick(point: CGPoint(x: 30, y: 30), timestamp: 1.12, commandDown: true))
        XCTAssertFalse(detector.registerClick(point: CGPoint(x: 31, y: 30), timestamp: 1.20, commandDown: true))
    }

    func testRejectsClicksOutsideTimingWindow() {
        var detector = TripleClickDetector()
        let point = CGPoint(x: 45, y: 45)

        XCTAssertFalse(detector.registerClick(point: point, timestamp: 1.00, commandDown: true))
        XCTAssertFalse(detector.registerClick(point: point, timestamp: 1.32, commandDown: true))
        XCTAssertFalse(detector.registerClick(point: point, timestamp: 1.90, commandDown: true))
    }

    func testCancelsWhenCommandIsReleased() {
        var detector = TripleClickDetector()
        let point = CGPoint(x: 90, y: 90)

        XCTAssertFalse(detector.registerClick(point: point, timestamp: 1.00, commandDown: true))
        XCTAssertFalse(detector.registerClick(point: point, timestamp: 1.12, commandDown: false))
        XCTAssertFalse(detector.registerClick(point: point, timestamp: 1.20, commandDown: true))
    }

    func testArmedPlainClickSuppressesMouseDownAndMouseUp() {
        let state = EventTapSuppressionState()
        state.configure(capturesPlainClick: true, capturesAreaDrag: false, excludedZones: [])

        XCTAssertTrue(state.shouldSuppress(type: .leftMouseDown, point: CGPoint(x: 120, y: 80), commandDown: false))
        XCTAssertTrue(state.shouldSuppress(type: .leftMouseUp, point: CGPoint(x: 120, y: 80), commandDown: false))
        XCTAssertFalse(state.shouldSuppress(type: .leftMouseUp, point: CGPoint(x: 120, y: 80), commandDown: false))
    }

    func testAreaDragSuppressesFullDragGesture() {
        let state = EventTapSuppressionState()
        state.configure(capturesPlainClick: false, capturesAreaDrag: true, excludedZones: [])

        XCTAssertTrue(state.shouldSuppress(type: .leftMouseDown, point: CGPoint(x: 40, y: 40), commandDown: false))
        XCTAssertTrue(state.shouldSuppress(type: .leftMouseDragged, point: CGPoint(x: 90, y: 96), commandDown: false))
        XCTAssertTrue(state.shouldSuppress(type: .leftMouseUp, point: CGPoint(x: 120, y: 128), commandDown: false))
        XCTAssertFalse(state.shouldSuppress(type: .leftMouseDragged, point: CGPoint(x: 140, y: 140), commandDown: false))
    }

    func testSuppressionRespectsFloatingControlExclusion() {
        let state = EventTapSuppressionState()
        let zone = GestureExclusionZone(
            frame: CGRect(x: 800, y: 620, width: 220, height: 120),
            screenFrame: CGRect(x: 0, y: 0, width: 1200, height: 800)
        )
        state.configure(capturesPlainClick: true, capturesAreaDrag: false, excludedZones: [zone])

        XCTAssertFalse(state.shouldSuppress(type: .leftMouseDown, point: CGPoint(x: 840, y: 660), commandDown: false))
        XCTAssertFalse(state.shouldSuppress(type: .leftMouseDown, point: CGPoint(x: 840, y: 140), commandDown: false))
        XCTAssertTrue(state.shouldSuppress(type: .leftMouseDown, point: CGPoint(x: 200, y: 140), commandDown: false))
    }

    func testArmedPlainCaptureSuppressesScrollWhileResizing() {
        let state = EventTapSuppressionState()
        state.configure(capturesPlainClick: true, capturesAreaDrag: false, excludedZones: [])

        XCTAssertTrue(state.shouldSuppress(type: .scrollWheel, point: CGPoint(x: 120, y: 80), commandDown: false))
    }

    func testScrollSuppressionRespectsFloatingControlExclusion() {
        let state = EventTapSuppressionState()
        let zone = GestureExclusionZone(
            frame: CGRect(x: 800, y: 620, width: 220, height: 120),
            screenFrame: CGRect(x: 0, y: 0, width: 1200, height: 800)
        )
        state.configure(capturesPlainClick: true, capturesAreaDrag: false, excludedZones: [zone])

        XCTAssertFalse(state.shouldSuppress(type: .scrollWheel, point: CGPoint(x: 840, y: 660), commandDown: false))
        XCTAssertTrue(state.shouldSuppress(type: .scrollWheel, point: CGPoint(x: 200, y: 140), commandDown: false))
    }
}
