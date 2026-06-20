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
                .frame(minWidth: 900, idealWidth: 980, maxWidth: 1180, minHeight: 620, idealHeight: 680, maxHeight: 820)
                .onAppear {
                    appDelegate.model = model
                    model.refreshPermissions()
                }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandMenu("Capture") {
                Button("Show Capture Control") {
                    model.showCapturePuck()
                }
                .keyboardShortcut("1", modifiers: [.command, .shift])

                Button(model.capturePuckVisible ? "Hide Capture Control" : "Show Capture Control") {
                    model.toggleCapturePuck()
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])

                Button("Cancel Capture") {
                    model.stopGestureMonitor()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Divider()

                Button("Copy Last PNG") {
                    model.copyLastCapture()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView(model: model)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let showCaptureControlNotification = Notification.Name("com.edgariraheta.CueShot.showCaptureControl")
    private static let selectCaptureModeNotification = Notification.Name("com.edgariraheta.CueShot.selectCaptureMode")
    private static let armCaptureNotification = Notification.Name("com.edgariraheta.CueShot.armCapture")
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
}
