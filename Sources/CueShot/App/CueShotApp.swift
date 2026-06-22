import AppKit
import SwiftUI

@MainActor
private enum CueShotAppEnvironment {
    static let model = AppModel()
}

@main
struct CueShotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = CueShotAppEnvironment.model

    var body: some Scene {
        WindowGroup("CueShot", id: "main") {
            ContentView(model: model)
                .frame(minWidth: 760, idealWidth: 860, maxWidth: 980, minHeight: 500, idealHeight: 560, maxHeight: 680)
                .preferredColorScheme(.dark)
                .onAppear {
                    appDelegate.model = model
                    model.refreshPermissions()
                }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandMenu("Capture") {
                CueShotCommandMenuButton(model: model, command: .showCaptureControl)
                CueShotCommandMenuButton(model: model, command: .toggleCaptureControl)
                CueShotCommandMenuButton(model: model, command: .armCapture)
                CueShotCommandMenuButton(model: model, command: .cancelCapture)

                Divider()

                CueShotCommandMenuButton(model: model, command: .selectElementMode)
                CueShotCommandMenuButton(model: model, command: .selectSelectionMode)
                CueShotCommandMenuButton(model: model, command: .selectWindowMode)
                CueShotCommandMenuButton(model: model, command: .selectAreaMode)
                CueShotCommandMenuButton(model: model, command: .selectScreenMode)
                CueShotCommandMenuButton(model: model, command: .selectOCRMode)

                Divider()

                CueShotCommandMenuButton(model: model, command: .copyLastPNG)
                CueShotCommandMenuButton(model: model, command: .openSettings)
                CueShotCommandMenuButton(model: model, command: .showOnboarding)
            }
        }

        Settings {
            SettingsView(model: model)
                .preferredColorScheme(.dark)
        }
    }
}

private struct CueShotCommandMenuButton: View {
    @ObservedObject var model: AppModel
    let command: CueShotCommand

    var body: some View {
        Button(menuTitle) {
            model.performCommand(command)
        }
        .cueKeyboardShortcut(model.shortcut(for: command))
    }

    private var menuTitle: String {
        switch command {
        case .toggleCaptureControl:
            model.capturePuckVisible ? "Hide Capture Control" : "Show Capture Control"
        case .openSettings:
            "Settings..."
        default:
            command.title
        }
    }
}

private extension View {
    @ViewBuilder
    func cueKeyboardShortcut(_ shortcut: CueShotShortcut) -> some View {
        if let key = shortcut.key {
            keyboardShortcut(key.keyEquivalent, modifiers: shortcut.eventModifiers)
        } else {
            self
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let showCaptureControlNotification = Notification.Name("com.edgariraheta.CueShot.showCaptureControl")
    private static let selectCaptureModeNotification = Notification.Name("com.edgariraheta.CueShot.selectCaptureMode")
    private static let armCaptureNotification = Notification.Name("com.edgariraheta.CueShot.armCapture")
    private static let testCodexHandoffNotification = Notification.Name("com.edgariraheta.CueShot.testCodexHandoff")
    private let menuBarController = MenuBarActivationController()
    weak var model: AppModel? {
        didSet {
            if let model {
                menuBarController.configure(model: model)
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let appModel = CueShotAppEnvironment.model
        model = appModel
        DiagnosticsLogger().record("app.launch modelReady showAtLaunch=\(appModel.showCaptureButtonAtLaunch)")
        NSApp.setActivationPolicy(.regular)
        NSApp.appearance = NSAppearance(named: .darkAqua)
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        appModel.refreshPermissions()
        DispatchQueue.main.async {
            appModel.applyLaunchPreferences()
        }
        configureSmokeAutomationIfNeeded()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        model?.refreshPermissions()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.stopGestureMonitor()
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func showCaptureControlFromNotification(_ notification: Notification) {
        DiagnosticsLogger().record("app.notification showCaptureControl")
        model?.showCapturePuck()
    }

    private func configureSmokeAutomationIfNeeded() {
        guard UserDefaults.standard.bool(forKey: "enableSmokeAutomation") else { return }

        DiagnosticsLogger().record("app.smokeAutomation enabled=true")
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(showCaptureControlFromNotification),
            name: Self.showCaptureControlNotification,
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(selectCaptureModeFromNotification),
            name: Self.selectCaptureModeNotification,
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(armCaptureFromNotification),
            name: Self.armCaptureNotification,
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(testCodexHandoffFromNotification),
            name: Self.testCodexHandoffNotification,
            object: nil
        )
    }

    @objc private func selectCaptureModeFromNotification(_ notification: Notification) {
        guard
            let rawMode = notification.userInfo?["mode"] as? String,
            let mode = CaptureMode(rawValue: rawMode)
        else {
            DiagnosticsLogger().record("app.notification selectCaptureMode invalid")
            return
        }

        DiagnosticsLogger().record("app.notification selectCaptureMode mode=\(mode.rawValue)")
        model?.selectMode(mode)
        model?.showCapturePuck()
    }

    @objc private func armCaptureFromNotification(_ notification: Notification) {
        DiagnosticsLogger().record("app.notification armCapture")
        model?.armCaptureFromFloatingControl()
    }

    @objc private func testCodexHandoffFromNotification(_ notification: Notification) {
        DiagnosticsLogger().record("app.notification testCodexHandoff")
        model?.testCodexHandoff()
    }
}
