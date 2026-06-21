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
    private let eventTapContext = GestureEventTapContext()
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

    func start(
        capturesPlainClick: Bool = false,
        capturesAreaDrag: Bool = false,
        excludedZones: [GestureExclusionZone] = [],
        resizeBindings: CaptureResizeBindings = CaptureResizeBindings()
    ) -> Bool {
        capturesNextPlainClick = capturesNextPlainClick || capturesPlainClick
        capturesNextAreaDrag = capturesNextAreaDrag || capturesAreaDrag
        isRunning = true
        areaDragStart = nil
        lastMoveEmittedAt = 0
        lastMoveEmittedPoint = nil
        eventTapContext.monitor = self
        eventTapContext.configure(
            capturesPlainClick: capturesNextPlainClick,
            capturesAreaDrag: capturesNextAreaDrag,
            excludedZones: excludedZones,
            resizeBindings: resizeBindings
        )

        guard eventTap == nil, localEventMonitor == nil, globalEventMonitor == nil else {
            return true
        }

        let mask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue) |
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let context = Unmanaged<GestureEventTapContext>.fromOpaque(userInfo).takeUnretainedValue()
            return context.handle(type: type, event: event)
        }

        let requiresEventSuppression = capturesNextPlainClick || capturesNextAreaDrag
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: requiresEventSuppression ? .defaultTap : .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(eventTapContext).toOpaque()
        )

        guard let tap else {
            stop()
            return false
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
        eventTapContext.reset()

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
        let mask: NSEvent.EventTypeMask = [.flagsChanged, .mouseMoved, .leftMouseDown, .leftMouseDragged, .leftMouseUp, .scrollWheel, .keyDown]

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

    fileprivate func handle(_ snapshot: GlobalGestureSnapshot) {
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
        case .scrollWheel:
            guard capturesNextPlainClick || snapshot.commandDown || commandDown else { return }
            guard let scrollDelta = snapshot.scrollDelta, scrollDelta != .zero else { return }
            emit(.resize(point: snapshot.point, deltaX: scrollDelta.dx, deltaY: scrollDelta.dy, axis: snapshot.resizeAxis))
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

struct GestureExclusionZone: Equatable, Sendable {
    let frame: CGRect
    let screenFrame: CGRect?
    let hitSlop: CGFloat

    init(frame: CGRect, screenFrame: CGRect?, hitSlop: CGFloat = 8) {
        self.frame = frame
        self.screenFrame = screenFrame
        self.hitSlop = hitSlop
    }

    func contains(_ point: CGPoint) -> Bool {
        let expandedFrame = frame.insetBy(dx: -hitSlop, dy: -hitSlop)
        if expandedFrame.contains(point) {
            return true
        }

        guard let screenFrame else {
            return false
        }

        let flippedPoint = CGPoint(
            x: point.x,
            y: screenFrame.maxY - (point.y - screenFrame.minY)
        )
        return expandedFrame.contains(flippedPoint)
    }
}

final class EventTapSuppressionState: @unchecked Sendable {
    private let lock = NSLock()
    private var capturesPlainClick = false
    private var capturesAreaDrag = false
    private var areaDragActive = false
    private var suppressMouseUpAfterPlainClick = false
    private var excludedZones: [GestureExclusionZone] = []

    func configure(capturesPlainClick: Bool, capturesAreaDrag: Bool, excludedZones: [GestureExclusionZone]) {
        lock.lock()
        self.capturesPlainClick = capturesPlainClick
        self.capturesAreaDrag = capturesAreaDrag
        self.excludedZones = excludedZones
        areaDragActive = false
        suppressMouseUpAfterPlainClick = false
        lock.unlock()
    }

    func reset() {
        lock.lock()
        capturesPlainClick = false
        capturesAreaDrag = false
        areaDragActive = false
        suppressMouseUpAfterPlainClick = false
        excludedZones = []
        lock.unlock()
    }

    func shouldSuppress(type: CGEventType, point: CGPoint, commandDown: Bool) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if excludedZones.contains(where: { $0.contains(point) }) {
            return false
        }

        switch type {
        case .leftMouseDown:
            if capturesAreaDrag && !commandDown {
                areaDragActive = true
                return true
            }

            if capturesPlainClick && !commandDown {
                suppressMouseUpAfterPlainClick = true
                return true
            }

            return false
        case .leftMouseDragged:
            return capturesAreaDrag && areaDragActive
        case .leftMouseUp:
            if capturesAreaDrag && areaDragActive {
                areaDragActive = false
                return true
            }

            if suppressMouseUpAfterPlainClick {
                suppressMouseUpAfterPlainClick = false
                return true
            }

            return false
        case .scrollWheel:
            return capturesPlainClick || capturesAreaDrag
        default:
            return false
        }
    }
}

private final class GestureEventTapContext: @unchecked Sendable {
    weak var monitor: GlobalGestureMonitor?
    private let suppressionState = EventTapSuppressionState()
    private var resizeBindings = CaptureResizeBindings()

    func configure(
        capturesPlainClick: Bool,
        capturesAreaDrag: Bool,
        excludedZones: [GestureExclusionZone],
        resizeBindings: CaptureResizeBindings
    ) {
        self.resizeBindings = resizeBindings
        suppressionState.configure(
            capturesPlainClick: capturesPlainClick,
            capturesAreaDrag: capturesAreaDrag,
            excludedZones: excludedZones
        )
    }

    func reset() {
        suppressionState.reset()
    }

    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let snapshot = GlobalGestureSnapshot(
            type: type,
            point: event.location,
            timestamp: TimeInterval(event.timestamp) / 1_000_000_000,
            commandDown: event.flags.contains(.maskCommand),
            activeResizeModifiers: Self.activeModifiers(for: event.flags),
            resizeBindings: resizeBindings,
            scrollDelta: Self.scrollDelta(for: event),
            keyCode: type == .keyDown ? event.getIntegerValueField(.keyboardEventKeycode) : nil
        )
        let shouldSuppress = suppressionState.shouldSuppress(
            type: type,
            point: snapshot.point,
            commandDown: snapshot.commandDown
        )
        let monitor = monitor

        Task { @MainActor [weak monitor] in
            monitor?.handle(snapshot)
        }

        return shouldSuppress ? nil : Unmanaged.passUnretained(event)
    }

    private static func scrollDelta(for event: CGEvent) -> CGVector? {
        let deltaX = bestScrollDelta(
            point: event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2),
            fixed: event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2),
            line: event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        )
        let deltaY = bestScrollDelta(
            point: event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1),
            fixed: event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1),
            line: event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        )

        guard deltaX != 0 || deltaY != 0 else { return nil }
        return CGVector(dx: deltaX, dy: deltaY)
    }

    private static func bestScrollDelta(point: Double, fixed: Double, line: Int64) -> CGFloat {
        if point != 0 {
            return CGFloat(point)
        }
        if fixed != 0 {
            return CGFloat(fixed)
        }
        return CGFloat(line)
    }

    private static func activeModifiers(for flags: CGEventFlags) -> Set<CaptureResizeModifier> {
        var modifiers: Set<CaptureResizeModifier> = []
        if flags.contains(.maskShift) {
            modifiers.insert(.shift)
        }
        if flags.contains(.maskAlternate) {
            modifiers.insert(.option)
        }
        if flags.contains(.maskControl) {
            modifiers.insert(.control)
        }
        if flags.contains(.maskCommand) {
            modifiers.insert(.command)
        }
        return modifiers
    }
}

private struct GlobalGestureSnapshot: Sendable {
    let type: CGEventType
    let point: CGPoint
    let timestamp: TimeInterval
    let commandDown: Bool
    let activeResizeModifiers: Set<CaptureResizeModifier>
    let resizeBindings: CaptureResizeBindings
    let scrollDelta: CGVector?
    let keyCode: Int64?

    init(
        type: CGEventType,
        point: CGPoint,
        timestamp: TimeInterval,
        commandDown: Bool,
        activeResizeModifiers: Set<CaptureResizeModifier> = [],
        resizeBindings: CaptureResizeBindings = CaptureResizeBindings(),
        scrollDelta: CGVector? = nil,
        keyCode: Int64? = nil
    ) {
        self.type = type
        self.point = point
        self.timestamp = timestamp
        self.commandDown = commandDown
        self.activeResizeModifiers = activeResizeModifiers
        self.resizeBindings = resizeBindings
        self.scrollDelta = scrollDelta
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
        case .scrollWheel:
            mappedType = .scrollWheel
        case .keyDown:
            mappedType = .keyDown
        default:
            return nil
        }

        type = mappedType
        point = event.cgEvent?.location ?? NSEvent.mouseLocation
        timestamp = event.timestamp
        commandDown = event.modifierFlags.contains(.command)
        activeResizeModifiers = Self.activeModifiers(for: event.modifierFlags)
        resizeBindings = CaptureResizeBindings()
        scrollDelta = event.type == .scrollWheel
            ? CGVector(dx: event.scrollingDeltaX, dy: event.scrollingDeltaY)
            : nil
        keyCode = event.type == .keyDown ? Int64(event.keyCode) : nil
    }

    var resizeAxis: CaptureResizeAxis {
        resizeBindings.axis(for: activeResizeModifiers)
    }

    private static func activeModifiers(for flags: NSEvent.ModifierFlags) -> Set<CaptureResizeModifier> {
        var modifiers: Set<CaptureResizeModifier> = []
        if flags.contains(.shift) {
            modifiers.insert(.shift)
        }
        if flags.contains(.option) {
            modifiers.insert(.option)
        }
        if flags.contains(.control) {
            modifiers.insert(.control)
        }
        if flags.contains(.command) {
            modifiers.insert(.command)
        }
        return modifiers
    }
}
