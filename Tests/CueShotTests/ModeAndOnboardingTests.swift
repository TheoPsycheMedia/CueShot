import CoreGraphics
import XCTest
@testable import CueShot

final class ModeAndOnboardingTests: XCTestCase {
    func testSelectionModeIsSeparateFromManualAreaMode() {
        XCTAssertTrue(CaptureMode.allCases.contains(.selection))
        XCTAssertEqual(CaptureMode.selection.title, "Selection")
        XCTAssertEqual(CaptureMode.selection.puckPickerTitle, "Select")
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

    func testScrollResizeCanAdjustWidthWithoutChangingHeight() {
        let screenFrame = CGRect(x: 0, y: 0, width: 600, height: 400)
        let target = CaptureTarget(
            point: CGPoint(x: 300, y: 200),
            screenFrame: screenFrame,
            rect: CGRect(x: 220, y: 150, width: 160, height: 100),
            sourceAppName: "CueShotTests",
            sourceBundleID: nil,
            axRole: "Estimated",
            axSubrole: nil,
            axTitle: nil,
            confidence: .estimated
        )

        let adjusted = CaptureRectAdjuster.resizedTarget(
            target,
            centeredAt: CGPoint(x: 300, y: 200),
            deltaX: 5,
            deltaY: 0,
            axis: .width
        )

        XCTAssertEqual(adjusted.confidence, .adjusted)
        XCTAssertGreaterThan(adjusted.rect.width, target.rect.width)
        XCTAssertEqual(adjusted.rect.height, target.rect.height, accuracy: 1)
    }

    func testScrollResizeClampsAdjustedRectangleToScreen() {
        let screenFrame = CGRect(x: 0, y: 0, width: 320, height: 240)
        let target = CaptureTarget(
            point: CGPoint(x: 10, y: 10),
            screenFrame: screenFrame,
            rect: CGRect(x: 0, y: 0, width: 200, height: 180),
            sourceAppName: "CueShotTests",
            sourceBundleID: nil,
            axRole: "Estimated",
            axSubrole: nil,
            axTitle: nil,
            confidence: .estimated
        )

        let adjusted = CaptureRectAdjuster.resizedTarget(
            target,
            centeredAt: CGPoint(x: 10, y: 10),
            deltaX: 0,
            deltaY: 80,
            axis: .both
        )

        XCTAssertEqual(adjusted.rect.minX, screenFrame.minX, accuracy: 1)
        XCTAssertEqual(adjusted.rect.minY, screenFrame.minY, accuracy: 1)
        XCTAssertLessThanOrEqual(adjusted.rect.maxX, screenFrame.maxX + 1)
        XCTAssertLessThanOrEqual(adjusted.rect.maxY, screenFrame.maxY + 1)
    }

    func testResizeBindingsMapSelectedModifiersToAxes() {
        let bindings = CaptureResizeBindings(widthModifier: .control, heightModifier: .command)

        XCTAssertEqual(bindings.axis(for: [.control]), .width)
        XCTAssertEqual(bindings.axis(for: [.command]), .height)
        XCTAssertEqual(bindings.axis(for: []), .both)
        XCTAssertEqual(bindings.axis(for: [.control, .command]), .both)
    }

    @MainActor
    func testResizeModifierPreferencesPersistAndAvoidDuplicates() {
        let suiteName = "CueShotTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let model = AppModel(userDefaults: defaults)
        model.widthResizeModifier = .control
        model.heightResizeModifier = .control

        XCTAssertEqual(model.heightResizeModifier, .control)
        XCTAssertEqual(model.widthResizeModifier, .option)

        let reloaded = AppModel(userDefaults: defaults)
        XCTAssertEqual(reloaded.widthResizeModifier, .option)
        XCTAssertEqual(reloaded.heightResizeModifier, .control)
    }

    @MainActor
    func testCommandShortcutsPersist() {
        let suiteName = "CueShotTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let model = AppModel(userDefaults: defaults)
        let shortcut = CueShotShortcut(key: .g, modifiers: [.command, .option])
        model.setShortcut(shortcut, for: .armCapture)

        let reloaded = AppModel(userDefaults: defaults)
        XCTAssertEqual(reloaded.shortcut(for: .armCapture), shortcut)
    }

    @MainActor
    func testCommandShortcutDuplicatesClearOlderCommand() {
        let suiteName = "CueShotTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let model = AppModel(userDefaults: defaults)
        let copyShortcut = model.shortcut(for: .copyLastPNG)
        model.setShortcut(copyShortcut, for: .showCaptureControl)

        XCTAssertEqual(model.shortcut(for: .showCaptureControl), copyShortcut)
        XCTAssertEqual(model.shortcut(for: .copyLastPNG), .unassigned)
    }

    func testShortcutDisplayTextUsesMacGlyphs() {
        let shortcut = CueShotShortcut(key: .one, modifiers: [.command, .shift])

        XCTAssertEqual(shortcut.displayText, "⇧⌘1")
        XCTAssertEqual(CueShotCommand.showCaptureControl.defaultShortcut.displayText, "⇧⌘1")
        XCTAssertEqual(CueShotShortcut.unassigned.displayText, "Unassigned")
    }

    @MainActor
    func testAutoHandoffDefaultsToClipboardOnly() {
        let suiteName = "CueShotTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let model = AppModel(userDefaults: defaults)

        XCTAssertFalse(model.autoPasteToCodex)
        XCTAssertEqual(model.destinationSummary, "Copy PNG to Clipboard")
        XCTAssertTrue(model.destinationFallbackSummary.contains("Press Cmd+V"))
    }

    @MainActor
    func testStaleAutoHandoffPreferenceMigratesToClipboardOnly() {
        let suiteName = "CueShotTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults.set(true, forKey: "autoPasteToCodex")

        let model = AppModel(userDefaults: defaults)

        XCTAssertFalse(model.autoPasteToCodex)
        XCTAssertEqual(model.destinationSummary, "Copy PNG to Clipboard")
        XCTAssertEqual(defaults.integer(forKey: "clipboardFirstMigrationVersion"), 1)
    }

    @MainActor
    func testAdvancedAppServerPreferenceCanPersistAfterMigration() {
        let suiteName = "CueShotTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults.set(1, forKey: "clipboardFirstMigrationVersion")
        defaults.set(true, forKey: "autoPasteToCodex")

        let model = AppModel(userDefaults: defaults)

        XCTAssertTrue(model.autoPasteToCodex)
        XCTAssertTrue(model.destinationSummary.contains("experimental App Server"))
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
        XCTAssertFalse(firstLaunch.showCaptureButtonAtLaunch)

        firstLaunch.selectMode(.selection)
        firstLaunch.autoPasteToCodex = false
        firstLaunch.showCaptureButtonAtLaunch = true
        firstLaunch.completeOnboarding()

        let secondLaunch = AppModel(userDefaults: defaults)
        XCTAssertEqual(secondLaunch.selectedMode, .selection)
        XCTAssertFalse(secondLaunch.autoPasteToCodex)
        XCTAssertTrue(secondLaunch.showCaptureButtonAtLaunch)
        XCTAssertFalse(secondLaunch.showOnboarding)
    }

    @MainActor
    func testChangingModeWhileArmedReturnsToReady() {
        let suiteName = "CueShotTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let model = AppModel(userDefaults: defaults)
        model.oneClickCaptureArmed = true
        model.gestureMonitorRunning = true
        model.captureState = .armed

        model.selectMode(.area)

        XCTAssertEqual(model.selectedMode, .area)
        XCTAssertFalse(model.oneClickCaptureArmed)
        XCTAssertFalse(model.gestureMonitorRunning)
        XCTAssertEqual(model.captureState, .ready)
        XCTAssertNil(model.currentTarget)
    }

    @MainActor
    func testChangingModeClearsStaleCaptureState() {
        let suiteName = "CueShotTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let model = AppModel(userDefaults: defaults)
        model.captureState = .copyFallback(reason: "Previous capture copied.")

        model.selectMode(.screen)

        XCTAssertEqual(model.selectedMode, .screen)
        XCTAssertEqual(model.captureState, .ready)
    }
}
