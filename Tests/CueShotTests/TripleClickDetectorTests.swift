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
}
