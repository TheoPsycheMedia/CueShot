import AppKit
import CoreGraphics
import Foundation

struct TripleClickDetector {
    private let maximumDuration: TimeInterval = 0.650
    private let maximumRadius: CGFloat = 6
    private var clicks: [(time: TimeInterval, point: CGPoint)] = []

    mutating func reset() {
        clicks.removeAll()
    }

    mutating func registerClick(point: CGPoint, timestamp: TimeInterval, commandDown: Bool) -> Bool {
        guard commandDown else {
            reset()
            return false
        }

        if let first = clicks.first {
            let outsideTime = timestamp - first.time > maximumDuration
            let outsideRadius = hypot(point.x - first.point.x, point.y - first.point.y) > maximumRadius
            if outsideTime || outsideRadius {
                clicks.removeAll()
            }
        }

        clicks.append((timestamp, point))

        guard clicks.count >= 3 else {
            return false
        }

        reset()
        return true
    }
}

@MainActor
final class GlobalGestureMonitor {
    var onEvent: ((GestureEvent) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var detector = TripleClickDetector()
    private var commandDown = false
    private var capturesNextPlainClick = false
    private var capturesNextAreaDrag = false
    private var areaDragStart: CGPoint?
    private var isRunning = false
    private var lastMoveEmittedAt: TimeInterval = 0
    private var lastMoveEmittedPoint: CGPoint?
    private let moveEmitInterval: TimeInterval = 0.050
    private let moveEmitDistance: CGFloat = 22

    func start(capturesPlainClick: Bool = false, capturesAreaDrag: Bool = false) -> Bool {
        capturesNextPlainClick = capturesNextPlainClick || capturesPlainClick
        capturesNextAreaDrag = capturesNextAreaDrag || capturesAreaDrag
        isRunning = true
        areaDragStart = nil
        lastMoveEmittedAt = 0
        lastMoveEmittedPoint = nil

        guard eventTap == nil, localEventMonitor == nil, globalEventMonitor == nil else {
            return true
        }

        installEventMonitors()

        let mask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let monitor = Unmanaged<GlobalGestureMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            let snapshot = GlobalGestureSnapshot(
                type: type,
                point: event.location,
                timestamp: TimeInterval(event.timestamp) / 1_000_000_000,
                commandDown: event.flags.contains(.maskCommand),
                keyCode: type == .keyDown ? event.getIntegerValueField(.keyboardEventKeycode) : nil
            )

            Task { @MainActor in
                monitor.handle(snapshot)
            }
            return Unmanaged.passUnretained(event)
        }

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap else {
            isRunning = localEventMonitor != nil || globalEventMonitor != nil
            return isRunning
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        isRunning = false

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil

        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
        }
        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
        }

        localEventMonitor = nil
        globalEventMonitor = nil
        detector.reset()
        commandDown = false
        capturesNextPlainClick = false
        capturesNextAreaDrag = false
        areaDragStart = nil
        lastMoveEmittedAt = 0
        lastMoveEmittedPoint = nil
    }

    private func installEventMonitors() {
        let mask: NSEvent.EventTypeMask = [.flagsChanged, .mouseMoved, .leftMouseDown, .leftMouseDragged, .leftMouseUp, .keyDown]

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            guard let snapshot = GlobalGestureSnapshot(event: event) else {
                return event
            }

            Task { @MainActor [weak self] in
                self?.handle(snapshot)
            }

            return event
        }

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            guard let snapshot = GlobalGestureSnapshot(event: event) else {
                return
            }

            Task { @MainActor [weak self] in
                self?.handle(snapshot)
            }
        }
    }

    private func handle(_ snapshot: GlobalGestureSnapshot) {
        if snapshot.type == .tapDisabledByTimeout || snapshot.type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return
        }

        guard isRunning else { return }

        switch snapshot.type {
        case .flagsChanged:
            if snapshot.commandDown && !commandDown {
                commandDown = true
                emit(.armed(point: snapshot.point))
            } else if !snapshot.commandDown && commandDown {
                commandDown = false
                detector.reset()
                emit(.cancelled)
            }
        case .mouseMoved:
            guard capturesNextPlainClick || snapshot.commandDown || commandDown else { return }
            guard shouldEmitMove(snapshot) else { return }
            if capturesNextPlainClick {
                emit(.moved(point: snapshot.point))
                return
            }
            commandDown = true
            emit(.moved(point: snapshot.point))
        case .leftMouseDown:
            if capturesNextAreaDrag && !snapshot.commandDown && !commandDown {
                areaDragStart = snapshot.point
                emit(.areaStarted(start: snapshot.point, current: snapshot.point))
                return
            }

            if capturesNextPlainClick && !snapshot.commandDown && !commandDown {
                let point = snapshot.point
                stop()
                emit(.click(point: point))
                return
            }

            guard snapshot.commandDown || commandDown else {
                detector.reset()
                return
            }

            commandDown = true
            emit(.armed(point: snapshot.point))

            if detector.registerClick(point: snapshot.point, timestamp: snapshot.timestamp, commandDown: true) {
                emit(.tripleClick(point: snapshot.point))
            }
        case .leftMouseDragged:
            guard capturesNextAreaDrag, let areaDragStart else { return }
            emit(.areaChanged(start: areaDragStart, current: snapshot.point))
        case .leftMouseUp:
            guard capturesNextAreaDrag, let areaDragStart else { return }
            let end = snapshot.point
            stop()
            emit(.areaFinished(start: areaDragStart, end: end))
        case .keyDown:
            if snapshot.keyCode == 53, capturesNextPlainClick || capturesNextAreaDrag || commandDown {
                stop()
                emit(.cancelled)
            }
        default:
            break
        }
    }

    private func emit(_ event: GestureEvent) {
        onEvent?(event)
    }

    private func shouldEmitMove(_ snapshot: GlobalGestureSnapshot) -> Bool {
        guard lastMoveEmittedAt > 0, let previousPoint = lastMoveEmittedPoint else {
            lastMoveEmittedAt = snapshot.timestamp
            lastMoveEmittedPoint = snapshot.point
            return true
        }

        let elapsed = snapshot.timestamp - lastMoveEmittedAt
        let distance = hypot(snapshot.point.x - previousPoint.x, snapshot.point.y - previousPoint.y)
        guard elapsed >= moveEmitInterval || distance >= moveEmitDistance else {
            return false
        }

        lastMoveEmittedAt = snapshot.timestamp
        lastMoveEmittedPoint = snapshot.point
        return true
    }
}

private struct GlobalGestureSnapshot: Sendable {
    let type: CGEventType
    let point: CGPoint
    let timestamp: TimeInterval
    let commandDown: Bool
    let keyCode: Int64?

    init(type: CGEventType, point: CGPoint, timestamp: TimeInterval, commandDown: Bool, keyCode: Int64? = nil) {
        self.type = type
        self.point = point
        self.timestamp = timestamp
        self.commandDown = commandDown
        self.keyCode = keyCode
    }

    init?(event: NSEvent) {
        let mappedType: CGEventType

        switch event.type {
        case .flagsChanged:
            mappedType = .flagsChanged
        case .mouseMoved:
            mappedType = .mouseMoved
        case .leftMouseDown:
            mappedType = .leftMouseDown
        case .leftMouseDragged:
            mappedType = .leftMouseDragged
        case .leftMouseUp:
            mappedType = .leftMouseUp
        case .keyDown:
            mappedType = .keyDown
        default:
            return nil
        }

        type = mappedType
        point = event.cgEvent?.location ?? NSEvent.mouseLocation
        timestamp = event.timestamp
        commandDown = event.modifierFlags.contains(.command)
        keyCode = event.type == .keyDown ? Int64(event.keyCode) : nil
    }
}
