import CoreGraphics
import XCTest
@testable import CueShot

final class ModeAndOnboardingTests: XCTestCase {
    func testSelectionModeIsSeparateFromManualAreaMode() {
        XCTAssertTrue(CaptureMode.allCases.contains(.selection))
        XCTAssertTrue(CaptureMode.allCases.contains(.ocr))
        XCTAssertEqual(CaptureMode.allCases.prefix(4), [.element, .window, .area, .screen])
        XCTAssertEqual(CaptureMode.selection.title, "Selection")
        XCTAssertEqual(CaptureMode.selection.puckPickerTitle, "Select")
        XCTAssertEqual(CaptureMode.selection.helpText, "Estimated crop around the next click.")
        XCTAssertEqual(CaptureMode.area.helpText, "Manual drag rectangle capture.")
        XCTAssertEqual(CaptureMode.ocr.title, "OCR")
        XCTAssertEqual(CaptureMode.ocr.helpText, "Estimated region capture with OCR text extraction.")
    }

    func testCaptureControlInitialPlacementLeavesUtilityMenuRoom() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1200, height: 800)
        let size = CGSize(width: 380, height: 64)

        let origin = CaptureControlPlacement.initialOrigin(for: size, visibleFrame: visibleFrame)
        let frame = CGRect(origin: origin, size: size)

        XCTAssertGreaterThanOrEqual(visibleFrame.maxX - frame.maxX, CaptureControlPlacement.utilityMenuClearance - 0.5)
        XCTAssertEqual(frame.maxY, visibleFrame.maxY - CaptureControlPlacement.topPadding, accuracy: 0.5)
    }

    func testCaptureControlResizeKeepsUtilityMenuRoom() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1200, height: 800)
        let current = CGRect(x: 792, y: 708, width: 380, height: 64)
        let resized = CaptureControlPlacement.resizedFrame(
            from: current,
            to: CGSize(width: 430, height: 142),
            visibleFrame: visibleFrame
        )

        XCTAssertGreaterThanOrEqual(visibleFrame.maxX - resized.maxX, CaptureControlPlacement.utilityMenuClearance - 0.5)
        XCTAssertGreaterThanOrEqual(resized.minX, visibleFrame.minX + CaptureControlPlacement.edgePadding - 0.5)
        XCTAssertGreaterThanOrEqual(resized.minY, visibleFrame.minY + CaptureControlPlacement.edgePadding - 0.5)
    }

    func testCaptureControlPlacementFitsNarrowScreens() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 560, height: 360)
        let size = CGSize(width: 430, height: 142)

        let origin = CaptureControlPlacement.initialOrigin(for: size, visibleFrame: visibleFrame)
        let frame = CGRect(origin: origin, size: size)

        XCTAssertGreaterThanOrEqual(frame.minX, visibleFrame.minX + CaptureControlPlacement.edgePadding - 0.5)
        XCTAssertLessThanOrEqual(frame.maxX, visibleFrame.maxX - CaptureControlPlacement.edgePadding + 0.5)
        XCTAssertGreaterThanOrEqual(frame.minY, visibleFrame.minY + CaptureControlPlacement.edgePadding - 0.5)
        XCTAssertLessThanOrEqual(frame.maxY, visibleFrame.maxY - CaptureControlPlacement.edgePadding + 0.5)
    }

    func testOCRTextNormalizationSkipsBlankLinesAndWhitespace() {
        let record = CaptureRecord(
            id: UUID(),
            createdAt: .now,
            mode: .ocr,
            confidence: "Estimated",
            sourceAppName: "CueShotTests",
            axRole: "Estimated",
            dimensions: "120 x 50",
            fileSize: "1 KB",
            handoffStatus: "Prepared",
            pngRelativePath: nil,
            recognizedText: "\n  first line  \n\n  second line  \n  "
        )

        XCTAssertEqual(record.normalizedOCRText, "first line\nsecond line")
    }

    @MainActor
    func testThemePreferencePersistsAndUpdatesDesignTokens() {
        let suiteName = "CueShotTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            CueColor.use(.optic)
        }

        let model = AppModel(userDefaults: defaults)
        XCTAssertEqual(model.selectedTheme, .optic)

        model.selectedTheme = .aurora
        XCTAssertEqual(CueColor.theme, .aurora)

        let reloaded = AppModel(userDefaults: defaults)
        XCTAssertEqual(reloaded.selectedTheme, .aurora)
        XCTAssertEqual(CueColor.theme, .aurora)
    }

    @MainActor
    func testThemeCyclingMatchesCodexMeterStyleMoodPattern() {
        let suiteName = "CueShotTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            CueColor.use(.optic)
        }

        let model = AppModel(userDefaults: defaults)

        model.cycleTheme()
        XCTAssertEqual(model.selectedTheme, .aurora)

        model.cycleTheme()
        XCTAssertEqual(model.selectedTheme, .moss)

        model.cycleTheme()
        XCTAssertEqual(model.selectedTheme, .cinder)

        model.cycleTheme()
        XCTAssertEqual(model.selectedTheme, .optic)
    }

    func testManualAreaTargetUsesDragRectangle() throws {
        let screenFrame = CGDisplayBounds(CGMainDisplayID())
        guard screenFrame.width > 0, screenFrame.height > 0 else {
            throw XCTSkip("Main display bounds are unavailable in this test environment.")
        }
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

    func testPreciseScrollStepUsesSmallStableAdjustment() {
        let step = CaptureRectAdjuster.scrollStep(for: 0.2)

        XCTAssertGreaterThan(step, 0)
        XCTAssertLessThan(step, 6)
    }

    func testLargeScrollDeltaIsClampedToAvoidJumping() {
        let step = CaptureRectAdjuster.scrollStep(for: 24)

        XCTAssertLessThanOrEqual(abs(step), 18)
    }

    func testPrecisionSelectionStatePreservesAnchorPointDuringResize() {
        let target = CaptureTarget(
            point: CGPoint(x: 300, y: 200),
            screenFrame: CGRect(x: 0, y: 0, width: 800, height: 600),
            rect: CGRect(x: 220, y: 150, width: 160, height: 100),
            sourceAppName: "CueShotTests",
            sourceBundleID: nil,
            axRole: "Estimated",
            axSubrole: nil,
            axTitle: nil,
            confidence: .estimated
        )
        let state = PrecisionSelectionState(
            baseTarget: target,
            anchorPoint: target.point,
            adjustedSize: CGSize(width: 220, height: 100),
            activeAxis: .width
        )
        let preview = CaptureRectAdjuster.targetWithAdjustedRect(
            state.baseTarget,
            centeredAt: state.anchorPoint,
            size: state.adjustedSize
        )

        XCTAssertEqual(preview.point.x, target.point.x, accuracy: 0.1)
        XCTAssertEqual(preview.point.y, target.point.y, accuracy: 0.1)
        XCTAssertEqual(preview.rect.width, 220, accuracy: 1)
        XCTAssertEqual(preview.rect.height, 100, accuracy: 1)
    }

    func testPrecisionSelectionStateMovesWithoutResettingAdjustedSize() {
        let target = CaptureTarget(
            point: CGPoint(x: 300, y: 200),
            screenFrame: CGRect(x: 0, y: 0, width: 800, height: 600),
            rect: CGRect(x: 220, y: 150, width: 160, height: 100),
            sourceAppName: "CueShotTests",
            sourceBundleID: nil,
            axRole: "Estimated",
            axSubrole: nil,
            axTitle: nil,
            confidence: .estimated
        )
        let state = PrecisionSelectionState(
            baseTarget: target,
            anchorPoint: target.point,
            adjustedSize: CGSize(width: 220, height: 100),
            activeAxis: .width
        )
        let nextBaseTarget = CaptureTarget(
            point: CGPoint(x: 420, y: 260),
            screenFrame: CGRect(x: 0, y: 0, width: 800, height: 600),
            rect: CGRect(x: 370, y: 220, width: 100, height: 80),
            sourceAppName: "NextTarget",
            sourceBundleID: nil,
            axRole: "Estimated",
            axSubrole: nil,
            axTitle: nil,
            confidence: .estimated
        )

        let moved = state.moving(to: CGPoint(x: 420, y: 260), baseTarget: nextBaseTarget)

        XCTAssertEqual(moved.anchorPoint.x, 420, accuracy: 0.1)
        XCTAssertEqual(moved.anchorPoint.y, 260, accuracy: 0.1)
        XCTAssertEqual(moved.adjustedSize.width, 220, accuracy: 0.1)
        XCTAssertEqual(moved.adjustedSize.height, 100, accuracy: 0.1)
        XCTAssertEqual(moved.baseTarget.sourceAppName, "NextTarget")
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

    func testCaptureCoordinateMapperTranslatesRectIntoDisplayLocalSpace() {
        let displayFrame = CGRect(x: -1728, y: 0, width: 1728, height: 1117)
        let captureRect = CGRect(x: -1500, y: 120, width: 240, height: 90)
        let sourceRect = CaptureCoordinateMapper.sourceRect(for: captureRect, in: displayFrame)

        XCTAssertEqual(sourceRect.minX, 228, accuracy: 1)
        XCTAssertEqual(sourceRect.minY, 120, accuracy: 1)
        XCTAssertEqual(sourceRect.width, 240, accuracy: 1)
        XCTAssertEqual(sourceRect.height, 90, accuracy: 1)
    }

    func testCaptureCoordinateMapperRoundsPixelSizeUsingDisplayScale() {
        let pixelSize = CaptureCoordinateMapper.outputSize(
            for: CGRect(x: 0, y: 0, width: 101.2, height: 50.4),
            displayScale: 2
        )

        XCTAssertEqual(pixelSize.width, 203, accuracy: 0.1)
        XCTAssertEqual(pixelSize.height, 101, accuracy: 0.1)
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

    func testAutomationPermissionHasExplicitStatusText() {
        XCTAssertEqual(AutomationPermissionStatus.granted.displayTitle, "Granted")
        XCTAssertEqual(AutomationPermissionStatus.denied.detail, "System Events denied")
        XCTAssertEqual(AutomationPermissionStatus.notDetermined.diagnosticTitle, "not requested")
        XCTAssertFalse(AutomationPermissionStatus.unknown.isGranted)
    }

    func testAutomationPermissionStateDoesNotReuseScreenLanguage() {
        let state = CaptureState.permissionNeeded(.automation)

        XCTAssertEqual(state.label, "Needs Automation")
        XCTAssertTrue(state.detail.contains("System Events"))
        XCTAssertTrue(state.detail.contains("Edit > Paste"))
        XCTAssertFalse(state.detail.contains("Screen Recording"))
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
    func testLegacyPastePreferenceCanPersistAfterMigration() {
        let suiteName = "CueShotTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        defaults.set(1, forKey: "clipboardFirstMigrationVersion")
        defaults.set(true, forKey: "autoPasteToCodex")

        let model = AppModel(userDefaults: defaults)

        XCTAssertTrue(model.autoPasteToCodex)
        XCTAssertTrue(model.destinationSummary.contains("visible paste"))
        XCTAssertTrue(model.destinationFallbackSummary.contains("Edit > Paste"))
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
    func testDockIconPreferencePersists() {
        let suiteName = "CueShotTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let model = AppModel(userDefaults: defaults)
        XCTAssertFalse(model.hideDockIconWhenMenuBarActive)

        model.hideDockIconWhenMenuBarActive = true

        let reloaded = AppModel(userDefaults: defaults)
        XCTAssertTrue(reloaded.hideDockIconWhenMenuBarActive)
        XCTAssertTrue(defaults.bool(forKey: "hideDockIconWhenMenuBarActive"))

        model.hideDockIconWhenMenuBarActive = false
    }

    @MainActor
    func testOnboardingCannotCompleteWithoutRequiredPermissions() {
        let suiteName = "CueShotTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let model = AppModel(userDefaults: defaults)
        model.permissions = PermissionStatus(
            accessibilityGranted: false,
            screenRecordingGranted: false,
            automationStatus: .granted
        )

        model.completeOnboarding()

        XCTAssertFalse(model.hasCompletedOnboarding)
        XCTAssertTrue(model.showOnboarding)
        XCTAssertEqual(model.captureState, .permissionNeeded(.screenRecording))
        XCTAssertTrue(model.lastErrorMessage?.contains("Screen Recording and Accessibility") == true)
        XCTAssertFalse(defaults.bool(forKey: "hasCompletedOnboarding"))
    }

    @MainActor
    func testOnboardingCanCompleteWithoutOptionalAutomation() {
        let suiteName = "CueShotTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let model = AppModel(userDefaults: defaults)
        model.permissions = PermissionStatus(
            accessibilityGranted: true,
            screenRecordingGranted: true,
            automationStatus: .denied
        )

        model.completeOnboarding()

        XCTAssertTrue(model.hasCompletedOnboarding)
        XCTAssertFalse(model.showOnboarding)
        XCTAssertTrue(defaults.bool(forKey: "hasCompletedOnboarding"))
    }

    @MainActor
    func testDismissingIncompleteOnboardingDoesNotPersistCompletion() {
        let suiteName = "CueShotTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let model = AppModel(userDefaults: defaults)
        model.permissions = PermissionStatus(
            accessibilityGranted: false,
            screenRecordingGranted: true,
            automationStatus: .notDetermined
        )

        model.dismissOnboardingForNow()

        XCTAssertFalse(model.hasCompletedOnboarding)
        XCTAssertFalse(model.showOnboarding)
        XCTAssertFalse(defaults.bool(forKey: "hasCompletedOnboarding"))

        let nextLaunch = AppModel(userDefaults: defaults)
        XCTAssertTrue(nextLaunch.showOnboarding)
    }

    func testPermissionStatusSeparatesRequiredAndOptionalPermissions() {
        let missingRequired = PermissionStatus(
            accessibilityGranted: false,
            screenRecordingGranted: false,
            automationStatus: .granted
        )
        XCTAssertFalse(missingRequired.capturePermissionsGranted)
        XCTAssertEqual(missingRequired.missingRequiredKinds, [.screenRecording, .accessibility])
        XCTAssertEqual(missingRequired.firstMissingRequiredKind, .screenRecording)

        let optionalAutomationMissing = PermissionStatus(
            accessibilityGranted: true,
            screenRecordingGranted: true,
            automationStatus: .denied
        )
        XCTAssertTrue(optionalAutomationMissing.capturePermissionsGranted)
        XCTAssertTrue(optionalAutomationMissing.missingRequiredKinds.isEmpty)
        XCTAssertFalse(optionalAutomationMissing.automationGranted)
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
        model.captureState = .copied(reason: "Previous capture copied.")

        model.selectMode(.screen)

        XCTAssertEqual(model.selectedMode, .screen)
        XCTAssertEqual(model.captureState, .ready)
    }

    @MainActor
    func testCaptureControlPresentationFollowsCoreWorkflowStates() {
        let suiteName = "CueShotTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let model = AppModel(userDefaults: defaults)
        let capture = CaptureRecord.samples[0]
        model.recentCaptures = [capture]
        model.selectedCaptureID = capture.id

        XCTAssertEqual(model.captureControlPresentation, .idle)

        model.captureState = .armed
        XCTAssertEqual(model.captureControlPresentation, .armed)

        model.captureState = .copied(reason: "PNG copied.")
        XCTAssertEqual(model.captureControlPresentation, .captured(capture))

        model.captureState = .permissionNeeded(.accessibility)
        XCTAssertEqual(model.captureControlPresentation, .permission(.accessibility))

        model.captureState = .failed(reason: "Area too small")
        XCTAssertEqual(model.captureControlPresentation, .failed("Area too small"))
    }
}
