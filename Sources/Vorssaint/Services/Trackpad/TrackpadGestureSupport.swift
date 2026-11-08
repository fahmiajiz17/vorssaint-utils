// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Carbon.HIToolbox
import CoreFoundation
import CoreGraphics
import Foundation

enum TrackpadSwipeFingers: Int, CaseIterable, Identifiable {
    case three = 3
    case four = 4

    var id: Int { rawValue }

    static func sanitized(_ value: Int) -> TrackpadSwipeFingers {
        TrackpadSwipeFingers(rawValue: value) ?? .three
    }
}

struct TrackpadAppSwipeConfiguration: Equatable {
    static let engageDistanceRange: ClosedRange<Double> = 0.015...0.15
    static let stepDistanceRange: ClosedRange<Double> = 0.03...0.25
    static let verticalGuard: Float = 0.05
    static let defaultEngageDistance = 0.05
    static let defaultStepDistance = 0.11
    static let rowStepScale: Float = 1.5

    var fingers: TrackpadSwipeFingers
    var reversed: Bool
    var engageDistance = Float(defaultEngageDistance)
    var stepDistance = Float(defaultStepDistance)
    var rows = false

    static let standard = TrackpadAppSwipeConfiguration(fingers: .three, reversed: false)

    var rowStepDistance: Float { stepDistance * Self.rowStepScale }

    static func sanitizedEngageDistance(_ value: Double) -> Double {
        sanitized(value, in: engageDistanceRange, fallback: defaultEngageDistance)
    }

    static func sanitizedStepDistance(_ value: Double) -> Double {
        sanitized(value, in: stepDistanceRange, fallback: defaultStepDistance)
    }

    private static func sanitized(_ value: Double, in range: ClosedRange<Double>, fallback: Double) -> Double {
        guard value.isFinite, value > 0 else { return fallback }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    static func load(from defaults: UserDefaults) -> TrackpadAppSwipeConfiguration {
        func number(_ key: String, fallback: Double) -> Double {
            defaults.object(forKey: key) == nil ? fallback : defaults.double(forKey: key)
        }
        let fingers = defaults.object(forKey: DefaultsKey.trackpadAppSwipeFingers) == nil
            ? TrackpadSwipeFingers.three
            : TrackpadSwipeFingers.sanitized(defaults.integer(forKey: DefaultsKey.trackpadAppSwipeFingers))
        return TrackpadAppSwipeConfiguration(
            fingers: fingers,
            reversed: defaults.bool(forKey: DefaultsKey.trackpadAppSwipeReversed),
            engageDistance: Float(sanitizedEngageDistance(
                number(DefaultsKey.trackpadAppSwipeEngageDistance, fallback: defaultEngageDistance))),
            stepDistance: Float(sanitizedStepDistance(
                number(DefaultsKey.trackpadAppSwipeStepDistance, fallback: defaultStepDistance))),
            rows: SwitcherTrackpadSwipe.rowsEnabled(in: defaults))
    }
}

enum TrackpadAppSwipeEvent: Equatable {
    case opened(direction: Int)
    case step(direction: Int)
    case row(direction: Int)
    case finished
}

struct TrackpadContactCentroid: Equatable {
    let x: Float
    let y: Float

    init?(_ contacts: [TrackpadContact]) {
        guard !contacts.isEmpty else { return nil }
        let count = Float(contacts.count)
        x = contacts.reduce(0) { $0 + $1.x } / count
        y = contacts.reduce(0) { $0 + $1.y } / count
    }
}

struct TrackpadAppSwipeRecognizer {
    static let axisDominance: Float = 1.3
    static let maxStepsPerFrame = 4

    struct Swipe: Equatable {
        var lastX: Float
        var lastY: Float
        var travelX: Float = 0
        var travelY: Float = 0
        var contactCount: Int
    }

    enum Phase: Equatable {
        case idle
        case ignored
        case tracking(startX: Float, startY: Float)
        case swiping(Swipe)
    }

    var configuration: TrackpadAppSwipeConfiguration
    private(set) var phase: Phase = .idle

    init(configuration: TrackpadAppSwipeConfiguration) {
        self.configuration = configuration
    }

    var isSwiping: Bool {
        if case .swiping = phase { return true }
        return false
    }

    mutating func reset() {
        phase = .idle
    }

    mutating func process(_ contacts: [TrackpadContact]) -> [TrackpadAppSwipeEvent] {
        let count = contacts.count
        let fingers = configuration.fingers.rawValue
        switch phase {
        case .idle:
            if count == fingers, let centroid = TrackpadContactCentroid(contacts) {
                phase = .tracking(startX: centroid.x, startY: centroid.y)
            } else if count > fingers {
                phase = .ignored
            }
            return []
        case .ignored:
            if count == 0 { phase = .idle }
            return []
        case .tracking(let startX, let startY):
            guard count == fingers, let centroid = TrackpadContactCentroid(contacts) else {
                phase = count > fingers ? .ignored : .idle
                return []
            }
            return track(centroid, startX: startX, startY: startY)
        case .swiping(var swipe):
            guard count >= fingers, let centroid = TrackpadContactCentroid(contacts) else {
                phase = count == 0 ? .idle : .ignored
                return [.finished]
            }
            guard count == swipe.contactCount else {
                swipe.lastX = centroid.x
                swipe.lastY = centroid.y
                swipe.contactCount = count
                phase = .swiping(swipe)
                return []
            }
            return advance(centroid, swipe: swipe)
        }
    }

    private mutating func track(_ centroid: TrackpadContactCentroid,
                                startX: Float, startY: Float) -> [TrackpadAppSwipeEvent] {
        let dx = centroid.x - startX
        let dy = centroid.y - startY
        let engage = configuration.engageDistance
        if abs(dy) >= max(engage, TrackpadAppSwipeConfiguration.verticalGuard),
           abs(dy) >= Self.axisDominance * abs(dx) {
            phase = .ignored
            return []
        }
        guard abs(dx) >= engage, abs(dx) >= Self.axisDominance * abs(dy) else { return [] }
        phase = .swiping(Swipe(lastX: centroid.x, lastY: centroid.y, contactCount: configuration.fingers.rawValue))
        return [.opened(direction: mapped(dx > 0 ? 1 : -1))]
    }

    private mutating func advance(_ centroid: TrackpadContactCentroid, swipe: Swipe) -> [TrackpadAppSwipeEvent] {
        var swipe = swipe
        swipe.travelX += centroid.x - swipe.lastX
        swipe.travelY += centroid.y - swipe.lastY
        swipe.lastX = centroid.x
        swipe.lastY = centroid.y
        let step = configuration.stepDistance
        var events: [TrackpadAppSwipeEvent] = []
        while abs(swipe.travelX) >= step, events.count < Self.maxStepsPerFrame {
            let forward = swipe.travelX > 0
            swipe.travelX += forward ? -step : step
            swipe.travelY = 0
            events.append(.step(direction: mapped(forward ? 1 : -1)))
        }
        if configuration.rows {
            let rowStep = configuration.rowStepDistance
            while abs(swipe.travelY) >= rowStep, events.count < Self.maxStepsPerFrame {
                let upward = swipe.travelY > 0
                swipe.travelY += upward ? -rowStep : rowStep
                swipe.travelX = 0
                events.append(.row(direction: upward ? -1 : 1))
            }
        } else {
            swipe.travelY = 0
        }
        if events.count == Self.maxStepsPerFrame {
            swipe.travelX = 0
            swipe.travelY = 0
        }
        phase = .swiping(swipe)
        return events
    }

    private func mapped(_ direction: Int) -> Int {
        configuration.reversed ? -direction : direction
    }
}

final class TrackpadExtraFingerScroll {
    static let shared = TrackpadExtraFingerScroll()
    static let momentumGrace: TimeInterval = 3

    private let lock = NSLock()
    private var fingers = 0
    private var mutesApps = false
    private var touching = false
    private var tailUntil: TimeInterval = 0

    var isTouching: Bool { lock.withLock { touching } }

    func configure(fingers: Int?, mutesApps: Bool) {
        lock.withLock {
            self.fingers = fingers ?? 0
            self.mutesApps = fingers != nil && mutesApps
            if fingers == nil {
                touching = false
                tailUntil = 0
            }
        }
    }

    func noteContacts(_ count: Int, at time: TimeInterval) {
        lock.withLock {
            guard fingers > 0 else { return }
            if count >= fingers {
                touching = true
            } else if count == 0, touching {
                touching = false
                tailUntil = time + Self.momentumGrace
            }
        }
    }

    func mutes(scrollPhase: Int64, momentumPhase: Int64, at time: TimeInterval) -> Bool {
        guard scrollPhase != 0 || momentumPhase != 0 else { return false }
        return lock.withLock {
            guard mutesApps else { return false }
            if touching { return true }
            let starts = scrollPhase == Int64(CGScrollPhase.began.rawValue) || scrollPhase == 128
            if starts {
                tailUntil = 0
                return false
            }
            return time < tailUntil
        }
    }

    static func silence(_ event: CGEvent) {
        for field: CGEventField in [
            .scrollWheelEventDeltaAxis1, .scrollWheelEventDeltaAxis2, .scrollWheelEventDeltaAxis3,
            .scrollWheelEventPointDeltaAxis1, .scrollWheelEventPointDeltaAxis2, .scrollWheelEventPointDeltaAxis3,
        ] {
            event.setIntegerValueField(field, value: 0)
        }
        for field: CGEventField in [
            .scrollWheelEventFixedPtDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis3,
        ] {
            event.setDoubleValueField(field, value: 0)
        }
    }
}

struct TrackpadSwitcherKeyStroke: Equatable {
    let keyCode: CGKeyCode
    let keyDown: Bool
    let flags: CGEventFlags

    static func == (lhs: TrackpadSwitcherKeyStroke, rhs: TrackpadSwitcherKeyStroke) -> Bool {
        lhs.keyCode == rhs.keyCode && lhs.keyDown == rhs.keyDown && lhs.flags.rawValue == rhs.flags.rawValue
    }
}

enum TrackpadSwitcherKeys {
    static let nativeShortcut = GlobalShortcut(keyCode: Int64(kVK_Tab), modifiers: [.command])

    private static let modifierOrder: [(GlobalShortcutModifiers, Int)] = [
        (.command, kVK_Command), (.option, kVK_Option), (.control, kVK_Control), (.shift, kVK_Shift),
    ]

    static func canStepBackward(_ shortcut: GlobalShortcut) -> Bool {
        shortcut.shiftIsNavigationModifier
    }

    static func open(_ shortcut: GlobalShortcut, backward: Bool) -> [TrackpadSwitcherKeyStroke] {
        var strokes: [TrackpadSwitcherKeyStroke] = []
        var held: GlobalShortcutModifiers = []
        for (modifier, keyCode) in modifierOrder where shortcut.modifiers.contains(modifier) {
            held.insert(modifier)
            strokes.append(TrackpadSwitcherKeyStroke(keyCode: CGKeyCode(keyCode), keyDown: true, flags: held.cgFlags))
        }
        return strokes + step(shortcut, backward: backward)
    }

    static func step(_ shortcut: GlobalShortcut, backward: Bool) -> [TrackpadSwitcherKeyStroke] {
        let key = CGKeyCode(truncatingIfNeeded: shortcut.keyCode)
        let base = shortcut.modifiers.cgFlags
        guard backward else {
            return [TrackpadSwitcherKeyStroke(keyCode: key, keyDown: true, flags: base),
                    TrackpadSwitcherKeyStroke(keyCode: key, keyDown: false, flags: base)]
        }
        guard canStepBackward(shortcut) else { return [] }
        let shifted = base.union(.maskShift)
        let shift = CGKeyCode(kVK_Shift)
        return [TrackpadSwitcherKeyStroke(keyCode: shift, keyDown: true, flags: shifted),
                TrackpadSwitcherKeyStroke(keyCode: key, keyDown: true, flags: shifted),
                TrackpadSwitcherKeyStroke(keyCode: key, keyDown: false, flags: shifted),
                TrackpadSwitcherKeyStroke(keyCode: shift, keyDown: false, flags: base)]
    }

    static func release(_ shortcut: GlobalShortcut) -> [TrackpadSwitcherKeyStroke] {
        var held = shortcut.modifiers
        var strokes: [TrackpadSwitcherKeyStroke] = []
        for (modifier, keyCode) in modifierOrder.reversed() where shortcut.modifiers.contains(modifier) {
            held.remove(modifier)
            strokes.append(TrackpadSwitcherKeyStroke(keyCode: CGKeyCode(keyCode), keyDown: false, flags: held.cgFlags))
        }
        return strokes
    }
}

enum TrackpadSwipeConflict: Equatable {
    case threeFingerDrag
    case systemSwipe(fingers: Int)
}

struct TrackpadSystemGestures: Equatable {
    static let domains = ["com.apple.AppleMultitouchTrackpad", "com.apple.driver.AppleBluetoothMultitouch.trackpad"]

    var threeFingerDrag: Bool
    var threeFingerHorizontalSwipe: Int
    var fourFingerHorizontalSwipe: Int

    func conflicts(for fingers: TrackpadSwipeFingers) -> [TrackpadSwipeConflict] {
        switch fingers {
        case .three:
            var found: [TrackpadSwipeConflict] = []
            if threeFingerDrag { found.append(.threeFingerDrag) }
            if threeFingerHorizontalSwipe != 0 { found.append(.systemSwipe(fingers: 3)) }
            return found
        case .four:
            return fourFingerHorizontalSwipe != 0 ? [.systemSwipe(fingers: 4)] : []
        }
    }

    static func read(_ value: (String, String) -> Any? = { key, domain in
        CFPreferencesCopyAppValue(key as CFString, domain as CFString)
    }) -> TrackpadSystemGestures {
        func number(_ key: String) -> Int {
            domains.compactMap { (value(key, $0) as? NSNumber)?.intValue }.max() ?? 0
        }
        return TrackpadSystemGestures(threeFingerDrag: number("TrackpadThreeFingerDrag") != 0,
                                      threeFingerHorizontalSwipe: number("TrackpadThreeFingerHorizSwipeGesture"),
                                      fourFingerHorizontalSwipe: number("TrackpadFourFingerHorizSwipeGesture"))
    }
}

enum TrackpadEdgeScrollSpeed: String, CaseIterable, Identifiable {
    case slow, normal, fast

    var id: String { rawValue }

    var pointsPerSecond: Double {
        switch self {
        case .slow: return 450
        case .normal: return 900
        case .fast: return 1800
        }
    }

    static func sanitized(_ raw: String?) -> TrackpadEdgeScrollSpeed {
        raw.flatMap(TrackpadEdgeScrollSpeed.init(rawValue:)) ?? .normal
    }
}

enum TrackpadScrollHeading: Equatable {
    case up, down, left, right

    var isVertical: Bool { self == .up || self == .down }

    var fingerSign: Float { self == .up || self == .right ? 1 : -1 }

    func scrollSign(naturalScrolling: Bool) -> Double {
        let finger = Double(fingerSign)
        if isVertical { return naturalScrolling ? -finger : finger }
        return naturalScrolling ? finger : -finger
    }
}

struct TrackpadEdgeScrollConfiguration: Equatable {
    static let edgeZoneRange: ClosedRange<Double> = 0.06...0.25
    static let defaultEdgeZone = 0.12

    var edgeZone: Float
    var speed: TrackpadEdgeScrollSpeed
    var accelerates: Bool
    var horizontal: Bool

    static let standard = TrackpadEdgeScrollConfiguration(edgeZone: Float(defaultEdgeZone), speed: .normal,
                                                          accelerates: true, horizontal: true)

    static func sanitizedEdgeZone(_ value: Double) -> Double {
        guard value.isFinite, value > 0 else { return defaultEdgeZone }
        return min(max(value, edgeZoneRange.lowerBound), edgeZoneRange.upperBound)
    }

    static func load(from defaults: UserDefaults) -> TrackpadEdgeScrollConfiguration {
        let zone = defaults.object(forKey: DefaultsKey.trackpadEdgeScrollZone) == nil
            ? defaultEdgeZone
            : defaults.double(forKey: DefaultsKey.trackpadEdgeScrollZone)
        func flag(_ key: String) -> Bool { defaults.object(forKey: key) == nil || defaults.bool(forKey: key) }
        return TrackpadEdgeScrollConfiguration(
            edgeZone: Float(sanitizedEdgeZone(zone)),
            speed: TrackpadEdgeScrollSpeed.sanitized(defaults.string(forKey: DefaultsKey.trackpadEdgeScrollSpeed)),
            accelerates: flag(DefaultsKey.trackpadEdgeScrollAccelerates),
            horizontal: flag(DefaultsKey.trackpadEdgeScrollHorizontal))
    }

    func pointsPerSecond(heldFor elapsed: TimeInterval) -> Double {
        guard elapsed.isFinite, elapsed > 0 else { return 0 }
        let rampIn = min(1, elapsed / TrackpadEdgeScrollRecognizer.rampInDuration)
        let growth = accelerates
            ? 1 + min(elapsed, TrackpadEdgeScrollRecognizer.accelerationDuration)
                / TrackpadEdgeScrollRecognizer.accelerationDuration * (TrackpadEdgeScrollRecognizer.maximumBoost - 1)
            : 1
        return speed.pointsPerSecond * rampIn * growth
    }
}

enum TrackpadEdgeScrollEvent: Equatable {
    case began(TrackpadScrollHeading)
    case ended
}

struct TrackpadEdgeScrollRecognizer {
    static let headingTravel: Float = 0.04
    static let headingWindow: TimeInterval = 0.3
    static let stallWindow: TimeInterval = 0.08
    static let stallSpeed: Float = 0.08
    static let holdDelay: TimeInterval = 0.12
    static let releaseDistance: Float = 0.03
    static let zoneHysteresis: Float = 0.03
    static let rampInDuration: TimeInterval = 0.25
    static let accelerationDuration: TimeInterval = 2.5
    static let maximumBoost = 2.5

    struct Sample: Equatable {
        let time: TimeInterval
        let x: Float
        let y: Float
    }

    enum Phase: Equatable {
        case idle
        case tracking
        case scrolling(TrackpadScrollHeading, anchorX: Float, anchorY: Float)
    }

    var configuration: TrackpadEdgeScrollConfiguration
    private(set) var phase: Phase = .idle
    private(set) var heading: TrackpadScrollHeading?
    private var samples: [Sample] = []
    private var stallSince: TimeInterval?

    init(configuration: TrackpadEdgeScrollConfiguration) {
        self.configuration = configuration
    }

    var isScrolling: Bool {
        if case .scrolling = phase { return true }
        return false
    }

    mutating func reset() {
        phase = .idle
        heading = nil
        samples = []
        stallSince = nil
    }

    mutating func process(_ contacts: [TrackpadContact], at time: TimeInterval) -> [TrackpadEdgeScrollEvent] {
        guard contacts.count == 2, let centroid = TrackpadContactCentroid(contacts) else {
            let wasScrolling = isScrolling
            reset()
            return wasScrolling ? [.ended] : []
        }
        if phase == .idle {
            phase = .tracking
            samples = []
        }
        samples.append(Sample(time: time, x: centroid.x, y: centroid.y))
        samples.removeAll { time - $0.time > Self.headingWindow }
        switch phase {
        case .idle, .tracking:
            return track(contacts, centroid: centroid, at: time)
        case .scrolling(let heading, let anchorX, let anchorY):
            let along = heading.isVertical ? centroid.y - anchorY : centroid.x - anchorX
            let retreated = along * heading.fingerSign <= -Self.releaseDistance
            let leftZone = !isAtEdge(contacts, heading: heading, slack: Self.zoneHysteresis)
            guard retreated || leftZone else { return [] }
            phase = .tracking
            self.heading = nil
            stallSince = nil
            samples = [Sample(time: time, x: centroid.x, y: centroid.y)]
            return [.ended]
        }
    }

    private mutating func track(_ contacts: [TrackpadContact], centroid: TrackpadContactCentroid,
                                at time: TimeInterval) -> [TrackpadEdgeScrollEvent] {
        updateHeading(centroid)
        guard let heading, isAtEdge(contacts, heading: heading, slack: 0), isStalled(at: time) else {
            stallSince = nil
            return []
        }
        let since = stallSince ?? time
        stallSince = since
        guard time - since >= Self.holdDelay else { return [] }
        stallSince = nil
        phase = .scrolling(heading, anchorX: centroid.x, anchorY: centroid.y)
        return [.began(heading)]
    }

    private mutating func updateHeading(_ centroid: TrackpadContactCentroid) {
        guard let oldest = samples.first else { return }
        let dx = centroid.x - oldest.x
        let dy = centroid.y - oldest.y
        if abs(dy) >= Self.headingTravel, abs(dy) >= abs(dx) {
            heading = dy > 0 ? .up : .down
        } else if configuration.horizontal, abs(dx) >= Self.headingTravel, abs(dx) > abs(dy) {
            heading = dx > 0 ? .right : .left
        }
    }

    private func isStalled(at time: TimeInterval) -> Bool {
        guard let last = samples.last,
              let reference = samples.last(where: { time - $0.time >= Self.stallWindow }) else { return false }
        let elapsed = Float(last.time - reference.time)
        guard elapsed > 0 else { return false }
        let distance = ((last.x - reference.x) * (last.x - reference.x)
            + (last.y - reference.y) * (last.y - reference.y)).squareRoot()
        return distance / elapsed < Self.stallSpeed
    }

    func isAtEdge(_ contacts: [TrackpadContact], heading: TrackpadScrollHeading, slack: Float) -> Bool {
        let zone = configuration.edgeZone + slack
        switch heading {
        case .up: return (contacts.map(\.y).max() ?? 0) >= 1 - zone
        case .down: return (contacts.map(\.y).min() ?? 1) <= zone
        case .right: return (contacts.map(\.x).max() ?? 0) >= 1 - zone
        case .left: return (contacts.map(\.x).min() ?? 1) <= zone
        }
    }
}

struct TrackpadScrollMotionLedger {
    static let window: TimeInterval = 0.4

    private var samples: [(time: TimeInterval, vertical: Double, horizontal: Double)] = []

    mutating func note(vertical: Double, horizontal: Double, at time: TimeInterval) {
        guard vertical.isFinite, horizontal.isFinite else { return }
        samples.append((time, vertical, horizontal))
        samples.removeAll { time - $0.time > Self.window }
    }

    mutating func reset() {
        samples = []
    }

    func sign(for heading: TrackpadScrollHeading, at time: TimeInterval) -> Double? {
        let total = samples.filter { time - $0.time <= Self.window }
            .reduce(0) { $0 + (heading.isVertical ? $1.vertical : $1.horizontal) }
        guard total != 0 else { return nil }
        return total > 0 ? 1 : -1
    }
}

struct TrackpadEdgeScrollPacer {
    private(set) var carry: Double = 0

    mutating func pixels(pointsPerSecond: Double, elapsed: TimeInterval, sign: Double) -> Int32 {
        guard pointsPerSecond.isFinite, elapsed.isFinite, elapsed > 0 else { return 0 }
        let distance = pointsPerSecond * min(elapsed, 0.05) * sign + carry
        let whole = distance.rounded(.towardZero)
        carry = distance - whole
        return Int32(clamping: Int(whole))
    }

    mutating func reset() {
        carry = 0
    }
}
