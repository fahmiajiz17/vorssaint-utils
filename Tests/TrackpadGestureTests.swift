// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Carbon.HIToolbox
import CoreGraphics
import Foundation

enum TrackpadGestureTests {
    static func run(_ suite: TestSuite) {
        appSwipeOpensAndSteps(suite)
        appSwipeIgnoresOtherGestures(suite)
        appSwipeFingerCounts(suite)
        switcherKeys(suite)
        systemConflicts(suite)
        edgeScrollEngages(suite)
        edgeScrollStops(suite)
        edgeScrollSpeed(suite)
        switcherSwipeDirection(suite)
        appSwipeRows(suite)
        extraFingerScroll(suite)
        rowClamp(suite)
        catalog(suite)
    }

    private static func fingers(_ count: Int, x: Float, y: Float = 0.5) -> [TrackpadContact] {
        (0..<count).map { TrackpadContact(id: Int32($0 + 1), x: x + Float($0) * 0.01, y: y + Float($0) * 0.01) }
    }

    private static func swipe(_ recognizer: inout TrackpadAppSwipeRecognizer,
                              _ frames: [[TrackpadContact]]) -> [TrackpadAppSwipeEvent] {
        frames.flatMap { recognizer.process($0) }
    }

    private static func appSwipeOpensAndSteps(_ suite: TestSuite) {
        var recognizer = TrackpadAppSwipeRecognizer(configuration: .standard)
        let step = TrackpadAppSwipeConfiguration.standard.stepDistance
        let events = swipe(&recognizer, [
            fingers(3, x: 0.3),
            fingers(3, x: 0.33),
            fingers(3, x: 0.36),
            fingers(3, x: 0.36 + step + 0.001),
            fingers(3, x: 0.36 + 2 * step + 0.002),
            fingers(3, x: 0.36 + step - 0.01),
            [],
        ])
        suite.expect(events == [.opened(direction: 1), .step(direction: 1), .step(direction: 1),
                                .step(direction: -1), .finished],
                     "a three-finger swipe right opens the switcher forward, steps with the fingers both ways and commits on lift")
        var reversed = TrackpadAppSwipeRecognizer(configuration: TrackpadAppSwipeConfiguration(
            fingers: .three, reversed: true))
        let left = swipe(&reversed, [fingers(3, x: 0.6), fingers(3, x: 0.5), fingers(2, x: 0.5)])
        suite.expect(left == [.opened(direction: 1), .finished],
                     "reversed direction turns a left swipe into forward, and lifting one finger commits")
        var flick = TrackpadAppSwipeRecognizer(configuration: .standard)
        let quick = swipe(&flick, [fingers(3, x: 0.5), fingers(3, x: 0.44), []])
        suite.expect(quick == [.opened(direction: -1), .finished],
                     "a quick flick left opens backward and commits at once")
        var jump = TrackpadAppSwipeRecognizer(configuration: .standard)
        _ = swipe(&jump, [fingers(3, x: 0.2), fingers(3, x: 0.26)])
        let added = swipe(&jump, [fingers(4, x: 0.6), fingers(4, x: 0.61)])
        suite.expect(added.isEmpty && jump.isSwiping,
                     "an extra finger landing mid-swipe never jumps the selection")
    }

    private static func appSwipeIgnoresOtherGestures(_ suite: TestSuite) {
        var vertical = TrackpadAppSwipeRecognizer(configuration: .standard)
        let up = swipe(&vertical, [fingers(3, x: 0.5, y: 0.3), fingers(3, x: 0.51, y: 0.4),
                                   fingers(3, x: 0.7, y: 0.45), []])
        suite.expect(up.isEmpty, "a vertical swipe stays with Mission Control and never opens the switcher")
        var twoFingers = TrackpadAppSwipeRecognizer(configuration: .standard)
        let scroll = swipe(&twoFingers, [fingers(2, x: 0.2), fingers(2, x: 0.5), []])
        suite.expect(scroll.isEmpty, "two-finger scrolling is never a switcher swipe")
        var crowd = TrackpadAppSwipeRecognizer(configuration: .standard)
        let five = swipe(&crowd, [fingers(5, x: 0.2), fingers(3, x: 0.2), fingers(3, x: 0.5), []])
        suite.expect(five.isEmpty, "a gesture that started with more fingers waits for every finger to lift")
        var still = TrackpadAppSwipeRecognizer(configuration: .standard)
        let resting = swipe(&still, [fingers(3, x: 0.5), fingers(3, x: 0.52), []])
        suite.expect(resting.isEmpty, "resting or tapping three fingers does nothing")
    }

    private static func appSwipeFingerCounts(_ suite: TestSuite) {
        var four = TrackpadAppSwipeRecognizer(configuration: TrackpadAppSwipeConfiguration(
            fingers: .four, reversed: false))
        let threeOnly = swipe(&four, [fingers(3, x: 0.2), fingers(3, x: 0.5), []])
        let fourSwipe = swipe(&four, [fingers(4, x: 0.2), fingers(4, x: 0.3), []])
        suite.expect(threeOnly.isEmpty && fourSwipe == [.opened(direction: 1), .finished],
                     "the four-finger setting leaves three-finger swipes alone")
        var short = TrackpadAppSwipeRecognizer(configuration: TrackpadAppSwipeConfiguration(
            fingers: .three, reversed: false, engageDistance: 0.02))
        let early = swipe(&short, [fingers(3, x: 0.5), fingers(3, x: 0.525)])
        var standard = TrackpadAppSwipeRecognizer(configuration: .standard)
        let waits = swipe(&standard, [fingers(3, x: 0.5), fingers(3, x: 0.525)])
        suite.expect(early == [.opened(direction: 1)] && waits.isEmpty,
                     "a shorter opening distance brings the switcher up sooner, the default waits for more travel")
        var drift = TrackpadAppSwipeRecognizer(configuration: TrackpadAppSwipeConfiguration(
            fingers: .three, reversed: false, engageDistance: 0.02))
        let slightRise = swipe(&drift, [fingers(3, x: 0.5, y: 0.5), fingers(3, x: 0.5, y: 0.53),
                                        fingers(3, x: 0.55, y: 0.53)])
        suite.expect(slightRise == [.opened(direction: 1)],
                     "a short opening distance does not make a slight vertical drift cancel the swipe")
        suite.expect(TrackpadAppSwipeConfiguration.sanitizedEngageDistance(1) == 0.15
                && TrackpadAppSwipeConfiguration.sanitizedEngageDistance(.nan)
                    == TrackpadAppSwipeConfiguration.defaultEngageDistance
                && TrackpadAppSwipeConfiguration.standard.engageDistance == 0.05
                && Defaults.registeredDefaults[DefaultsKey.trackpadAppSwipeEngageDistance] as? Double == 0.05,
                     "the opening distance defaults to the earlier distance and stays in range")
        suite.expect(TrackpadSwipeFingers.sanitized(7) == .three && TrackpadSwipeFingers.sanitized(4) == .four,
                     "an unknown finger count falls back to three")
        var quick = TrackpadAppSwipeRecognizer(configuration: TrackpadAppSwipeConfiguration(
            fingers: .three, reversed: false, stepDistance: 0.04))
        let many = swipe(&quick, [fingers(3, x: 0.2), fingers(3, x: 0.26), fingers(3, x: 0.305),
                                  fingers(3, x: 0.35), fingers(3, x: 0.395)])
        var slow = TrackpadAppSwipeRecognizer(configuration: TrackpadAppSwipeConfiguration(
            fingers: .three, reversed: false, stepDistance: 0.2))
        let few = swipe(&slow, [fingers(3, x: 0.2), fingers(3, x: 0.26), fingers(3, x: 0.305),
                                fingers(3, x: 0.35), fingers(3, x: 0.395)])
        suite.expect(many.filter { $0 == .step(direction: 1) }.count == 3 && few == [.opened(direction: 1)],
                     "a shorter distance per app moves through the list faster")
        suite.expect(TrackpadAppSwipeConfiguration.sanitizedStepDistance(9) == 0.25
                && TrackpadAppSwipeConfiguration.sanitizedStepDistance(0) == 0.11
                && TrackpadAppSwipeConfiguration.standard.stepDistance == Float(0.11)
                && Defaults.registeredDefaults[DefaultsKey.trackpadAppSwipeStepDistance] as? Double == 0.11,
                     "the distance per app keeps its earlier default and stays in range")
    }

    private static func switcherKeys(_ suite: TestSuite) {
        let command = TrackpadSwitcherKeys.nativeShortcut
        let tab = CGKeyCode(kVK_Tab)
        suite.expect(TrackpadSwitcherKeys.open(command, backward: false) == [
            TrackpadSwitcherKeyStroke(keyCode: CGKeyCode(kVK_Command), keyDown: true, flags: .maskCommand),
            TrackpadSwitcherKeyStroke(keyCode: tab, keyDown: true, flags: .maskCommand),
            TrackpadSwitcherKeyStroke(keyCode: tab, keyDown: false, flags: .maskCommand),
        ], "opening presses Command and then Tab, like a person would")
        suite.expect(TrackpadSwitcherKeys.step(command, backward: true) == [
            TrackpadSwitcherKeyStroke(keyCode: CGKeyCode(kVK_Shift), keyDown: true, flags: [.maskCommand, .maskShift]),
            TrackpadSwitcherKeyStroke(keyCode: tab, keyDown: true, flags: [.maskCommand, .maskShift]),
            TrackpadSwitcherKeyStroke(keyCode: tab, keyDown: false, flags: [.maskCommand, .maskShift]),
            TrackpadSwitcherKeyStroke(keyCode: CGKeyCode(kVK_Shift), keyDown: false, flags: .maskCommand),
        ], "a backward step is one Shift-Tab chord while Command stays held")
        suite.expect(TrackpadSwitcherKeys.release(command) == [
            TrackpadSwitcherKeyStroke(keyCode: CGKeyCode(kVK_Command), keyDown: false, flags: []),
        ], "lifting releases Command so nothing stays latched")
        let optionCommand = GlobalShortcut(keyCode: Int64(kVK_Tab), modifiers: [.option, .command])
        let release = TrackpadSwitcherKeys.release(optionCommand)
        suite.expect(release.last?.flags == [] && release.count == 2,
                     "every modifier of a custom shortcut is released")
        let shiftShortcut = GlobalShortcut(keyCode: Int64(kVK_Tab), modifiers: [.shift, .command])
        suite.expect(TrackpadSwitcherKeys.step(shiftShortcut, backward: true).isEmpty,
                     "a shortcut that already uses Shift cannot step back, so nothing is pressed")
    }

    private static func systemConflicts(_ suite: TestSuite) {
        let values: [String: [String: Int]] = [
            "com.apple.AppleMultitouchTrackpad": ["TrackpadThreeFingerDrag": 1,
                                                  "TrackpadThreeFingerHorizSwipeGesture": 0,
                                                  "TrackpadFourFingerHorizSwipeGesture": 2],
            "com.apple.driver.AppleBluetoothMultitouch.trackpad": ["TrackpadThreeFingerHorizSwipeGesture": 0],
        ]
        let gestures = TrackpadSystemGestures.read { key, domain in values[domain]?[key].map(NSNumber.init(value:)) }
        suite.expect(gestures.conflicts(for: .three) == [.threeFingerDrag],
                     "three-finger drag is reported against a three-finger swipe")
        suite.expect(gestures.conflicts(for: .four) == [.systemSwipe(fingers: 4)],
                     "the system full-screen swipe is reported against a four-finger swipe")
        let clean = TrackpadSystemGestures(threeFingerDrag: false, threeFingerHorizontalSwipe: 0,
                                           fourFingerHorizontalSwipe: 0)
        suite.expect(clean.conflicts(for: .three).isEmpty, "no warning once the system gestures are out of the way")
    }

    private static func twoFingers(_ x: Float, _ y: Float) -> [TrackpadContact] {
        [TrackpadContact(id: 1, x: x - 0.05, y: y), TrackpadContact(id: 2, x: x + 0.05, y: y)]
    }

    private static func run(_ recognizer: inout TrackpadEdgeScrollRecognizer,
                            _ frames: [(x: Float, y: Float, time: TimeInterval)]) -> [TrackpadEdgeScrollEvent] {
        frames.flatMap { recognizer.process(twoFingers($0.x, $0.y), at: $0.time) }
    }

    private static func reachTop(_ recognizer: inout TrackpadEdgeScrollRecognizer) -> [TrackpadEdgeScrollEvent] {
        var frames: [(x: Float, y: Float, time: TimeInterval)] = []
        for index in 0..<10 {
            frames.append((0.5, 0.5 + Float(index) * 0.045, Double(index) * 0.016))
        }
        for index in 0..<20 {
            frames.append((0.5, 0.95, 0.16 + Double(index) * 0.016))
        }
        return run(&recognizer, frames)
    }

    private static func edgeScrollEngages(_ suite: TestSuite) {
        var recognizer = TrackpadEdgeScrollRecognizer(configuration: .standard)
        let events = reachTop(&recognizer)
        suite.expect(events == [.began(.up)] && recognizer.isScrolling,
                     "two fingers scrolling up that rest at the top edge keep the page scrolling")
        var resting = TrackpadEdgeScrollRecognizer(configuration: .standard)
        let still = run(&resting, (0..<30).map { (0.5, 0.95, Double($0) * 0.016) })
        suite.expect(still.isEmpty, "fingers simply resting at the edge without scrolling there do nothing")
        var sideways = TrackpadEdgeScrollRecognizer(configuration: TrackpadEdgeScrollConfiguration(
            edgeZone: 0.12, speed: .normal, accelerates: true, horizontal: false))
        var frames: [(x: Float, y: Float, time: TimeInterval)] = []
        for index in 0..<10 { frames.append((0.4 + Float(index) * 0.05, 0.5, Double(index) * 0.016)) }
        for index in 0..<20 { frames.append((0.9, 0.5, 0.16 + Double(index) * 0.016)) }
        suite.expect(run(&sideways, frames).isEmpty,
                     "side edges stay off when horizontal edge scrolling is switched off")
    }

    private static func edgeScrollStops(_ suite: TestSuite) {
        var lifted = TrackpadEdgeScrollRecognizer(configuration: .standard)
        _ = reachTop(&lifted)
        suite.expect(lifted.process([], at: 1) == [.ended] && !lifted.isScrolling,
                     "lifting the fingers stops the scrolling")
        var retreat = TrackpadEdgeScrollRecognizer(configuration: .standard)
        _ = reachTop(&retreat)
        suite.expect(retreat.process(twoFingers(0.5, 0.9), at: 1) == [.ended],
                     "sliding back from the edge stops the scrolling")
        var third = TrackpadEdgeScrollRecognizer(configuration: .standard)
        _ = reachTop(&third)
        let three = [TrackpadContact(id: 1, x: 0.4, y: 0.95), TrackpadContact(id: 2, x: 0.5, y: 0.95),
                     TrackpadContact(id: 3, x: 0.6, y: 0.95)]
        suite.expect(third.process(three, at: 1) == [.ended], "a third finger stops the scrolling")
    }

    private static func edgeScrollSpeed(_ suite: TestSuite) {
        let steady = TrackpadEdgeScrollConfiguration(edgeZone: 0.12, speed: .normal, accelerates: false, horizontal: true)
        let growing = TrackpadEdgeScrollConfiguration.standard
        suite.expect(steady.pointsPerSecond(heldFor: 0.05) < steady.pointsPerSecond(heldFor: 1)
                && steady.pointsPerSecond(heldFor: 1) == steady.pointsPerSecond(heldFor: 5),
                     "scrolling eases in and then holds a steady pace")
        suite.expect(growing.pointsPerSecond(heldFor: 5) > growing.pointsPerSecond(heldFor: 1)
                && growing.pointsPerSecond(heldFor: 5)
                    == TrackpadEdgeScrollSpeed.normal.pointsPerSecond * TrackpadEdgeScrollRecognizer.maximumBoost,
                     "holding longer speeds up to a bounded maximum")
        suite.expect(TrackpadScrollHeading.up.scrollSign(naturalScrolling: true) == -1
                && TrackpadScrollHeading.up.scrollSign(naturalScrolling: false) == 1
                && TrackpadScrollHeading.right.scrollSign(naturalScrolling: true) == 1,
                     "the fallback direction follows the natural scrolling setting")
        var ledger = TrackpadScrollMotionLedger()
        ledger.note(vertical: -12, horizontal: 1, at: 1)
        ledger.note(vertical: -8, horizontal: 0, at: 1.1)
        suite.expect(ledger.sign(for: .up, at: 1.2) == -1 && ledger.sign(for: .up, at: 3) == nil,
                     "the measured direction comes from the scroll the fingers were just making")
        var pacer = TrackpadEdgeScrollPacer()
        let total = (0..<120).reduce(Int32(0)) { sum, _ in
            sum + pacer.pixels(pointsPerSecond: 900, elapsed: 1.0 / 120.0, sign: -1)
        }
        suite.expect(abs(Int(total) + 900) <= 1, "a second of scrolling at 900 points travels 900 points")
        suite.expect(TrackpadEdgeScrollConfiguration.sanitizedEdgeZone(1) == 0.25
                && TrackpadEdgeScrollConfiguration.sanitizedEdgeZone(.nan) == TrackpadEdgeScrollConfiguration.defaultEdgeZone,
                     "the edge size stays in range")
    }

    private static func switcherSwipeDirection(_ suite: TestSuite) {
        func gesture(vertical: Int32, horizontal: Int32, phase: CGScrollPhase) -> CGEvent {
            let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
                                wheel1: vertical, wheel2: horizontal, wheel3: 0)!
            event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
            event.setIntegerValueField(.scrollWheelEventScrollPhase, value: Int64(phase.rawValue))
            event.timestamp = 1_000_000_000
            return event
        }
        let step = Int32(SwitcherScrollNavigation.gestureStep)
        let natural = SwitcherTrackpadSwipe(followsFingers: true, rows: false, invertedFromDevice: true)
        var navigation = SwitcherScrollNavigation()
        suite.expect(navigation.selectionDelta(for: gesture(vertical: 0, horizontal: step, phase: .began),
                                               swipe: natural) == 1,
                     "with natural scrolling, fingers moving right move the selection right")
        navigation = SwitcherScrollNavigation()
        suite.expect(navigation.selectionDelta(for: gesture(vertical: -step * 2, horizontal: 0, phase: .began),
                                               swipe: natural) == 0,
                     "an upward swipe leaves the selection alone by default")
        let traditional = SwitcherTrackpadSwipe(followsFingers: true, rows: true, invertedFromDevice: false)
        navigation = SwitcherScrollNavigation()
        suite.expect(navigation.selectionDelta(for: gesture(vertical: 0, horizontal: -step, phase: .began),
                                               swipe: traditional) == 1,
                     "without natural scrolling, fingers moving right still move the selection right")
        navigation = SwitcherScrollNavigation()
        let rowStep = Int32(SwitcherScrollNavigation.rowStep)
        suite.expect(navigation.selectionStep(for: gesture(vertical: -rowStep, horizontal: 0, phase: .began),
                                              swipe: traditional) == SwitcherScrollStep(rows: 1),
                     "with vertical swipes on, fingers moving down move the selection forward")
        let legacy = SwitcherTrackpadSwipe(followsFingers: false, rows: false, invertedFromDevice: true)
        navigation = SwitcherScrollNavigation()
        suite.expect(navigation.selectionDelta(for: gesture(vertical: 0, horizontal: step, phase: .began),
                                               swipe: legacy) == -1,
                     "turning finger direction off keeps the earlier scroll mapping")
        let wheel = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: -3, wheel2: 0, wheel3: 0)!
        navigation = SwitcherScrollNavigation()
        suite.expect(navigation.selectionDelta(for: wheel, swipe: natural) == 1,
                     "a mouse wheel keeps its own mapping")
    }

    private static func appSwipeRows(_ suite: TestSuite) {
        var rows = TrackpadAppSwipeRecognizer(configuration: TrackpadAppSwipeConfiguration(
            fingers: .three, reversed: false, rows: true))
        let rowStep = TrackpadAppSwipeConfiguration.standard.rowStepDistance
        let moved = swipe(&rows, [fingers(3, x: 0.3, y: 0.6), fingers(3, x: 0.36, y: 0.6),
                                  fingers(3, x: 0.36, y: 0.6 - rowStep - 0.01),
                                  fingers(3, x: 0.36, y: 0.61), []])
        suite.expect(moved == [.opened(direction: 1), .row(direction: 1), .row(direction: -1), .finished],
                     "with rows on, sliding down moves a row down and sliding back up returns")
        var off = TrackpadAppSwipeRecognizer(configuration: .standard)
        let ignored = swipe(&off, [fingers(3, x: 0.3, y: 0.6), fingers(3, x: 0.36, y: 0.6),
                                   fingers(3, x: 0.36, y: 0.3), []])
        suite.expect(ignored == [.opened(direction: 1), .finished],
                     "with rows off, vertical travel after opening changes nothing")
        var drift = TrackpadAppSwipeRecognizer(configuration: TrackpadAppSwipeConfiguration(
            fingers: .three, reversed: true, rows: true))
        let step = TrackpadAppSwipeConfiguration.standard.stepDistance
        let sideways = swipe(&drift, [fingers(3, x: 0.3, y: 0.6), fingers(3, x: 0.36, y: 0.6),
                                      fingers(3, x: 0.36 + step + 0.001, y: 0.56),
                                      fingers(3, x: 0.36 + 2 * step + 0.002, y: 0.52)])
        suite.expect(sideways == [.opened(direction: -1), .step(direction: -1), .step(direction: -1)],
                     "a sideways swipe drifting downward never jumps rows, and reversing flips only sideways steps")
    }

    private static func extraFingerScroll(_ suite: TestSuite) {
        let guardian = TrackpadExtraFingerScroll()
        let changed = Int64(CGScrollPhase.changed.rawValue)
        let began = Int64(CGScrollPhase.began.rawValue)
        guardian.configure(fingers: 3, mutesApps: true)
        guardian.noteContacts(2, at: 0)
        suite.expect(!guardian.mutes(scrollPhase: changed, momentumPhase: 0, at: 0) && !guardian.isTouching,
                     "two-finger scrolling is left alone")
        guardian.noteContacts(3, at: 0.1)
        suite.expect(guardian.mutes(scrollPhase: changed, momentumPhase: 0, at: 0.1) && guardian.isTouching,
                     "scroll from a three-finger touch is muted")
        guardian.noteContacts(2, at: 0.2)
        suite.expect(guardian.mutes(scrollPhase: changed, momentumPhase: 0, at: 0.2),
                     "lifting one finger first keeps the rest of that touch muted")
        guardian.noteContacts(0, at: 0.3)
        suite.expect(guardian.mutes(scrollPhase: 0, momentumPhase: 2, at: 0.5) && !guardian.isTouching,
                     "the momentum a three-finger touch leaves behind is muted too")
        suite.expect(!guardian.mutes(scrollPhase: began, momentumPhase: 0, at: 0.6)
                && !guardian.mutes(scrollPhase: 0, momentumPhase: 2, at: 0.7),
                     "a fresh two-finger scroll ends the muting at once")
        suite.expect(!guardian.mutes(scrollPhase: 0, momentumPhase: 0, at: 0.7),
                     "a mouse wheel is never muted")
        let open = TrackpadExtraFingerScroll()
        open.configure(fingers: 3, mutesApps: false)
        open.noteContacts(3, at: 0)
        suite.expect(open.isTouching && !open.mutes(scrollPhase: changed, momentumPhase: 0, at: 0),
                     "with the option off apps keep the scroll, while the switcher still knows a swipe is under way")
        open.configure(fingers: nil, mutesApps: true)
        suite.expect(!open.isTouching, "switching the swipe off forgets the touch")
        let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
                            wheel1: 12, wheel2: -7, wheel3: 0)!
        TrackpadExtraFingerScroll.silence(event)
        suite.expect(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == 0
                && event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2) == 0
                && event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1) == 0,
                     "a muted scroll keeps its phase but moves nothing")
    }

    private static func rowClamp(_ suite: TestSuite) {
        suite.expect(SwitcherSupport.rowClampedPosition(3, delta: 1, count: 10, columns: 4) == 3
                && SwitcherSupport.rowClampedPosition(4, delta: -1, count: 10, columns: 4) == 4
                && SwitcherSupport.rowClampedPosition(5, delta: 1, count: 10, columns: 4) == 6,
                     "sideways steps stop at the ends of their row")
        suite.expect(SwitcherSupport.rowClampedPosition(9, delta: 1, count: 10, columns: 4) == 9
                && SwitcherSupport.rowClampedPosition(8, delta: 3, count: 10, columns: 4) == 9,
                     "a short last row ends at its last item")
        suite.expect(SwitcherSupport.rowClampedPosition(2, delta: 5, count: 6, columns: 6) == 5
                && SwitcherSupport.rowClampedPosition(2, delta: 5, count: 6, columns: 0) == 5,
                     "a single-row layout clamps to the list itself")
    }

    private static func catalog(_ suite: TestSuite) {
        let feature = AppFeature.trackpadGestures
        suite.expect(feature.group == .mouseKeyboard && feature.permissions == [.accessibility]
                && feature.enabledKeys == [DefaultsKey.trackpadAppSwipeEnabled, DefaultsKey.trackpadEdgeScrollEnabled]
                && !feature.installedByDefault,
                     "trackpad gestures sit with the input features, need Accessibility and are opt-in")
        let registered = Defaults.registeredDefaults
        suite.expect(registered[DefaultsKey.trackpadAppSwipeEnabled] as? Bool == false
                && registered[DefaultsKey.trackpadEdgeScrollEnabled] as? Bool == false
                && registered[DefaultsKey.trackpadAppSwipeFingers] as? Int == 3
                && registered[DefaultsKey.switcherSwipeFollowsFingers] as? Bool == true
                && registered[DefaultsKey.switcherSwipeVertical] as? Bool == false
                && registered[DefaultsKey.panelControlTrackpadGestures] as? Bool == true,
                     "gestures start off with three fingers, and the switcher follows the fingers sideways only")
        let backup = SettingsBackupSupport.exportKeys()
        let keys = [DefaultsKey.trackpadAppSwipeEnabled, DefaultsKey.trackpadAppSwipeFingers,
                    DefaultsKey.trackpadAppSwipeStepDistance, DefaultsKey.trackpadAppSwipeReversed,
                    DefaultsKey.trackpadAppSwipeExclusive, DefaultsKey.switcherSwipeStaysInRow,
                    DefaultsKey.trackpadAppSwipeHaptics, DefaultsKey.trackpadEdgeScrollEnabled,
                    DefaultsKey.trackpadEdgeScrollZone, DefaultsKey.trackpadEdgeScrollSpeed,
                    DefaultsKey.trackpadEdgeScrollAccelerates, DefaultsKey.trackpadEdgeScrollHorizontal,
                    DefaultsKey.switcherSwipeFollowsFingers, DefaultsKey.switcherSwipeVertical]
        suite.expect(keys.allSatisfy(backup.contains), "every trackpad gesture preference travels with the backup")
        for language in AppLanguage.allCases {
            let strings = FeatureStrings.trackpadGestures(language)
            let names = TrackpadSwipeFingers.allCases.map { strings.name($0) }
                + [strings.stepCaption, strings.exclusiveCaption, strings.staysInRowToggle, strings.staysInRowCaption]
                + TrackpadEdgeScrollSpeed.allCases.map { strings.name($0) }
            suite.expect(!strings.pageTitle.isEmpty && names.allSatisfy { !$0.isEmpty }
                    && strings.appSwipeCaption(fingers: 3).contains("3")
                    && strings.exclusiveToggle(fingers: 3).contains("3")
                    && strings.conflict(.systemSwipe(fingers: 4)).contains("4"),
                         "trackpad gesture strings are complete in \(language.rawValue)")
        }
    }
}
