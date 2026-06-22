import AppKit
import Combine

@MainActor
final class MenuBarActivationController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private weak var model: AppModel?
    private var cancellables: Set<AnyCancellable> = []

    func configure(model: AppModel) {
        self.model = model
        cancellables.removeAll()

        guard let button = statusItem.button else { return }
        button.image = statusImage()
        button.imagePosition = .imageLeft
        button.target = self
        button.action = #selector(statusItemPressed(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateStatusButton()

        model.$captureState
            .sink { [weak self] _ in
                self?.updateStatusButton()
            }
            .store(in: &cancellables)
    }

    @objc private func statusItemPressed(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            openMenu()
        } else {
            model?.showCapturePuck()
        }
    }

    @objc private func stopCapture() {
        model?.stopGestureMonitor()
    }

    @objc private func armCapture() {
        model?.activateCaptureFromMenuBar()
    }

    @objc private func showButton() {
        model?.showCapturePuck()
    }

    @objc private func hideButton() {
        model?.hideCapturePuck()
    }

    @objc private func openMainWindow() {
        model?.openMainWindow()
    }

    @objc private func openSettings() {
        model?.openSettings()
    }

    @objc private func openOnboarding() {
        model?.openOnboarding()
    }

    @objc private func copyLastPNG() {
        model?.copyLastCapture()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func openMenu() {
        let menu = NSMenu()
        let armed = model?.oneClickCaptureArmed == true
        let buttonVisible = model?.capturePuckVisible == true

        if armed {
            menu.addItem(menuItem(title: "Cancel Capture", action: #selector(stopCapture), key: ""))
        } else {
            menu.addItem(menuItem(title: "Arm Capture", action: #selector(armCapture), key: ""))
        }
        menu.addItem(menuItem(title: buttonVisible ? "Hide Capture Control" : "Show Capture Control", action: buttonVisible ? #selector(hideButton) : #selector(showButton), key: ""))
        menu.addItem(.separator())
        menu.addItem(menuItem(title: "Open CueShot", action: #selector(openMainWindow), key: ""))
        menu.addItem(menuItem(title: "Settings...", action: #selector(openSettings), key: ","))
        menu.addItem(menuItem(title: "Onboarding", action: #selector(openOnboarding), key: ""))
        menu.addItem(menuItem(title: "Copy Last PNG", action: #selector(copyLastPNG), key: ""))
        menu.addItem(.separator())
        menu.addItem(menuItem(title: "Quit CueShot", action: #selector(quit), key: "q"))

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func menuItem(title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    private func updateStatusButton() {
        guard let button = statusItem.button else { return }
        let label = model?.captureState.menuBarLabel ?? "Ready"
        button.title = " \(label)"
        button.toolTip = "CueShot \(label)"
        button.setAccessibilityLabel("CueShot \(label)")
    }

    private func statusImage() -> NSImage? {
        if let image = NSImage(systemSymbolName: "scope", accessibilityDescription: "CueShot Capture") {
            image.isTemplate = true
            return image
        }

        return NSImage(named: NSImage.touchBarRecordStartTemplateName)
    }
}

private extension CaptureState {
    var menuBarLabel: String {
        switch self {
        case .permissionNeeded(let kind):
            switch kind {
            case .accessibility: "Needs AX"
            case .screenRecording: "Needs Screen"
            case .automation: "Needs Automation"
            }
        case .copied:
            "Copied"
        case .failed:
            "Failed"
        case .pasteAttempted:
            "Paste Attempted"
        case .codexAppServerAccepted:
            "App Server"
        case .codexNotFocused:
            "Needs Codex"
        default:
            label
        }
    }
}
