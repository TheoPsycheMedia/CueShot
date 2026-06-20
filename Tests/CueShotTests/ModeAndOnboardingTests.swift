import CoreGraphics
import XCTest
@testable import CueShot

final class ModeAndOnboardingTests: XCTestCase {
    func testSelectionModeIsSeparateFromManualAreaMode() {
        XCTAssertTrue(CaptureMode.allCases.contains(.selection))
        XCTAssertEqual(CaptureMode.selection.title, "Selection")
        XCTAssertEqual(CaptureMode.selection.helpText, "Estimated crop around the next click.")
        XCTAssertEqual(CaptureMode.area.helpText, "Manual drag rectangle capture.")
    }

    func testManualAreaTargetUsesDragRectangle() {
        let screenFrame = CGDisplayBounds(CGMainDisplayID())
        let start = CGPoint(x: screenFrame.midX - 80, y: screenFrame.midY - 40)
        let end = CGPoint(x: screenFrame.midX + 120, y: screenFrame.midY + 110)
        let target = AXHitTestService().areaTarget(from: start, to: end)

        XCTAssertEqual(target.confidence, .manualArea)
        XCTAssertEqual(target.axRole, "ManualArea")
        XCTAssertEqual(target.rect.width, 200, accuracy: 1)
        XCTAssertEqual(target.rect.height, 150, accuracy: 1)
    }

    @MainActor
    func testOnboardingAndCapturePreferencesPersist() {
        let suiteName = "CueShotTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let firstLaunch = AppModel(userDefaults: defaults)
        XCTAssertTrue(firstLaunch.showOnboarding)

        firstLaunch.selectMode(.selection)
        firstLaunch.autoPasteToCodex = false
        firstLaunch.completeOnboarding()

        let secondLaunch = AppModel(userDefaults: defaults)
        XCTAssertEqual(secondLaunch.selectedMode, .selection)
        XCTAssertFalse(secondLaunch.autoPasteToCodex)
        XCTAssertFalse(secondLaunch.showOnboarding)
    }
}
