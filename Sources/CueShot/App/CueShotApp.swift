import AppKit
import SwiftUI

@main
struct CueShotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

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
    private let menuBarController = MenuBarActivationController()
    weak var model: AppModel? {
        didSet {
            if let model {
                menuBarController.configure(model: model)
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        model?.refreshPermissions()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        model?.refreshPermissions()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.stopGestureMonitor()
    }
}
