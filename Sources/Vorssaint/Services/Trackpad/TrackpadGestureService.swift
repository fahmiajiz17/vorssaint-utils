// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import IOKit

final class TrackpadGestureService: ObservableObject {
    static let shared = TrackpadGestureService()

    static let edgeScrollMarker: Int64 = 0x5654_4553

    @Published private(set) var isRunning = false
    @Published private(set) var touchDeviceMissing = false
    @Published private(set) var edgeScrolling = false
    @Published private(set) var systemGestures = TrackpadSystemGestures(threeFingerDrag: false,
                                                                        threeFingerHorizontalSwipe: 0,
                                                                        fourFingerHorizontalSwipe: 0)

    private let stateLock = NSLock()
    private var appSwipe = TrackpadAppSwipeRecognizer(configuration: .standard)
    private var edgeScroll = TrackpadEdgeScrollRecognizer(configuration: .standard)
    private var appSwipeOn = false
    private var edgeScrollOn = false
    private var activeDevice: UnsafeMutableRawPointer?

    private var deviceList: CFArray?
    private var observers: [Any] = []
    private var hotplugPort: IONotificationPortRef?
    private var hotplugIterators: [io_iterator_t] = []

    private let tapLock = NSLock()
    private var scrollTap: CFMachPort?
    private var scrollSource: CFRunLoopSource?
    private var motion = TrackpadScrollMotionLedger()
    private var scrollTemplate: CGEvent?

    private var hapticsEnabled = true
    private var heldShortcut: GlobalShortcut?
    private var heldOwnSwitcher = false
    private var heldStaysInRow = false
    private var edgeConfiguration = TrackpadEdgeScrollConfiguration.standard
    private var scrollTimer: Timer?
    private var scrollHeading: TrackpadScrollHeading?
    private var scrollSign: Double = 1
    private var scrollStartedAt: TimeInterval = 0
    private var lastScrollTick: TimeInterval = 0
    private var pacer = TrackpadEdgeScrollPacer()

    private init() {
        SessionActivity.shared.onChange { [weak self] _ in
            self?.syncWithPreferences()
        }
    }

    var strings: TrackpadGestureStrings { FeatureStrings.trackpadGestures(L10n.shared.language) }

    func syncWithPreferences() {
        let defaults = UserDefaults.standard
        let available = AppFeature.trackpadGestures.isAvailable
        let swipeWanted = available && defaults.bool(forKey: DefaultsKey.trackpadAppSwipeEnabled)
        let scrollWanted = available && defaults.bool(forKey: DefaultsKey.trackpadEdgeScrollEnabled)
        let exclusive = swipeWanted && (defaults.object(forKey: DefaultsKey.trackpadAppSwipeExclusive) == nil
            || defaults.bool(forKey: DefaultsKey.trackpadAppSwipeExclusive))
        let swipeConfiguration = TrackpadAppSwipeConfiguration.load(from: defaults)
        let scrollConfiguration = TrackpadEdgeScrollConfiguration.load(from: defaults)
        hapticsEnabled = defaults.object(forKey: DefaultsKey.trackpadAppSwipeHaptics) == nil
            || defaults.bool(forKey: DefaultsKey.trackpadAppSwipeHaptics)
        edgeConfiguration = scrollConfiguration
        stateLock.withLock {
            if appSwipe.configuration != swipeConfiguration || !swipeWanted { appSwipe.reset() }
            if edgeScroll.configuration != scrollConfiguration || !scrollWanted { edgeScroll.reset() }
            appSwipe.configuration = swipeConfiguration
            edgeScroll.configuration = scrollConfiguration
            appSwipeOn = swipeWanted
            edgeScrollOn = scrollWanted
        }
        if !swipeWanted { releaseSwitcher() }
        if !scrollWanted { stopAutoScroll() }
        refreshSystemGestures()
        if SessionActivitySupport.tapShouldRun(
            featureWanted: swipeWanted || scrollWanted,
            accessibilityGranted: AXIsProcessTrusted(),
            sessionIsActive: SessionActivity.shared.isActive
        ) {
            start(scrollTap: scrollWanted || exclusive,
                  swipeFingers: swipeWanted ? swipeConfiguration.fingers.rawValue : nil,
                  exclusive: exclusive)
        } else {
            stop()
        }
    }

    func suspend() { stop() }

    func refreshSystemGestures() {
        let read = TrackpadSystemGestures.read()
        if read != systemGestures { systemGestures = read }
    }

    private func start(scrollTap wantsScrollTap: Bool, swipeFingers: Int?, exclusive: Bool) {
        guard TrackpadMultitouch.available else {
            touchDeviceMissing = true
            return
        }
        TrackpadExtraFingerScroll.shared.configure(fingers: swipeFingers, mutesApps: exclusive)
        if wantsScrollTap { installScrollTap() } else { removeScrollTap() }
        startMultitouch()
        installObservers()
        if !isRunning { isRunning = true }
    }

    private func stop() {
        TrackpadExtraFingerScroll.shared.configure(fingers: nil, mutesApps: false)
        removeScrollTap()
        stopMultitouch()
        removeObservers()
        releaseSwitcher()
        stopAutoScroll()
        if isRunning { isRunning = false }
        if touchDeviceMissing { touchDeviceMissing = false }
    }

    private func installScrollTap() {
        guard tapLock.withLock({ scrollTap }) == nil else { return }
        guard let created = CGEvent.tapCreate(
            tap: ScrollWheelSupport.tapLocation,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.scrollWheel.rawValue),
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let service = Unmanaged<TrackpadGestureService>.fromOpaque(userInfo).takeUnretainedValue()
                service.observeScroll(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0)
        tapLock.withLock {
            scrollTap = created
            scrollSource = source
        }
        if let source { PointerTapRunLoop.add(source) }
        CGEvent.tapEnable(tap: created, enable: true)
    }

    private func removeScrollTap() {
        let (port, source) = tapLock.withLock { () -> (CFMachPort?, CFRunLoopSource?) in
            let current = (scrollTap, scrollSource)
            scrollTap = nil
            scrollSource = nil
            motion.reset()
            scrollTemplate = nil
            return current
        }
        if let port { CGEvent.tapEnable(tap: port, enable: false) }
        if let source { PointerTapRunLoop.remove(source, invalidating: port) }
    }

    private func observeScroll(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if SessionActivity.shared.isActive, let port = tapLock.withLock({ scrollTap }) {
                CGEvent.tapEnable(tap: port, enable: true)
            }
            return
        }
        guard type == .scrollWheel,
              event.getIntegerValueField(.eventSourceUserData) != Self.edgeScrollMarker else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let phase = event.getIntegerValueField(.scrollWheelEventScrollPhase)
        let momentum = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
        if TrackpadExtraFingerScroll.shared.mutes(scrollPhase: phase, momentumPhase: momentum, at: now) {
            TrackpadExtraFingerScroll.silence(event)
            return
        }
        guard momentum == 0, stateLock.withLock({ edgeScrollOn }) else { return }
        guard phase == Int64(CGScrollPhase.began.rawValue) || phase == Int64(CGScrollPhase.changed.rawValue) else {
            return
        }
        let vertical = Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1))
        let horizontal = Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2))
        let copy = event.copy()
        tapLock.withLock {
            motion.note(vertical: vertical, horizontal: horizontal, at: now)
            if let copy { scrollTemplate = copy }
        }
    }

    private func restartMultitouch() {
        guard deviceList != nil else { return }
        releaseSwitcher()
        stopAutoScroll()
        stopMultitouch()
        startMultitouch()
    }

    private func startMultitouch() {
        guard deviceList == nil else { return }
        guard let list = TrackpadMultitouch.deviceList() else {
            touchDeviceMissing = true
            return
        }
        var started = false
        for index in 0..<CFArrayGetCount(list) {
            guard let raw = CFArrayGetValueAtIndex(list, index) else { continue }
            let device = UnsafeMutableRawPointer(mutating: raw)
            guard TrackpadMultitouch.isTrackpad(device) else { continue }
            TrackpadMultitouch.register(device, trackpadGestureContactCallback)
            TrackpadMultitouch.start(device)
            started = true
        }
        deviceList = list
        touchDeviceMissing = !started
    }

    private func stopMultitouch() {
        guard let list = deviceList else { return }
        for index in 0..<CFArrayGetCount(list) {
            guard let raw = CFArrayGetValueAtIndex(list, index) else { continue }
            let device = UnsafeMutableRawPointer(mutating: raw)
            guard TrackpadMultitouch.isTrackpad(device) else { continue }
            TrackpadMultitouch.unregister(device, trackpadGestureContactCallback)
            TrackpadMultitouch.stop(device)
        }
        deviceList = nil
        stateLock.withLock {
            appSwipe.reset()
            edgeScroll.reset()
            activeDevice = nil
        }
    }

    private func installObservers() {
        guard observers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            self?.releaseSwitcher()
            self?.stopAutoScroll()
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            self?.restartMultitouch()
        })
        installHotplugObserver()
    }

    private func installHotplugObserver() {
        guard hotplugPort == nil else { return }
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        IONotificationPortSetDispatchQueue(port, DispatchQueue.main)
        let context = Unmanaged.passUnretained(self).toOpaque()
        var iterators: [io_iterator_t] = []
        for notification in [kIOFirstMatchNotification, kIOTerminatedNotification] {
            var iterator: io_iterator_t = 0
            let result = IOServiceAddMatchingNotification(
                port,
                notification,
                IOServiceMatching("AppleMultitouchDevice"),
                { context, iterator in
                    guard let context else { return }
                    while case let entry = IOIteratorNext(iterator), entry != 0 {
                        IOObjectRelease(entry)
                    }
                    let service = Unmanaged<TrackpadGestureService>.fromOpaque(context).takeUnretainedValue()
                    service.restartMultitouch()
                },
                context,
                &iterator
            )
            guard result == KERN_SUCCESS else {
                if iterator != 0 { IOObjectRelease(iterator) }
                for registered in iterators { IOObjectRelease(registered) }
                IONotificationPortDestroy(port)
                return
            }
            while case let entry = IOIteratorNext(iterator), entry != 0 {
                IOObjectRelease(entry)
            }
            iterators.append(iterator)
        }
        hotplugPort = port
        hotplugIterators = iterators
    }

    private func removeObservers() {
        let center = NSWorkspace.shared.notificationCenter
        for observer in observers {
            center.removeObserver(observer)
        }
        observers = []
        for iterator in hotplugIterators { IOObjectRelease(iterator) }
        hotplugIterators.removeAll()
        if let hotplugPort {
            IONotificationPortDestroy(hotplugPort)
            self.hotplugPort = nil
        }
    }

    fileprivate func contactFrame(device: UnsafeMutableRawPointer?,
                                  touches: UnsafeMutableRawPointer?,
                                  count: Int) {
        let now = ProcessInfo.processInfo.systemUptime
        let contacts = TrackpadMultitouch.contacts(touches: touches, count: count)
        stateLock.lock()
        let busy = appSwipe.phase != .idle || edgeScroll.phase != .idle
        if busy, let activeDevice, activeDevice != device {
            stateLock.unlock()
            return
        }
        let frame = contacts ?? []
        TrackpadExtraFingerScroll.shared.noteContacts(frame.count, at: now)
        let swipeEvents = appSwipeOn ? appSwipe.process(frame) : []
        let scrollEvents = edgeScrollOn ? edgeScroll.process(frame, at: now) : []
        activeDevice = appSwipe.phase != .idle || edgeScroll.phase != .idle ? device : nil
        stateLock.unlock()
        guard !swipeEvents.isEmpty || !scrollEvents.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in
            self?.handle(swipeEvents)
            self?.handle(scrollEvents)
        }
    }

    private func handle(_ events: [TrackpadAppSwipeEvent]) {
        for event in events {
            switch event {
            case .opened(let direction):
                guard isRunning else { return }
                releaseSwitcher()
                let own = ownSwitcherShortcut()
                let shortcut = own ?? TrackpadSwitcherKeys.nativeShortcut
                heldShortcut = shortcut
                heldOwnSwitcher = own != nil
                heldStaysInRow = own != nil && SwitcherTrackpadSwipe.staysInRow(in: .standard)
                post(TrackpadSwitcherKeys.open(shortcut, backward: direction < 0))
                haptic()
            case .step(let direction):
                guard let shortcut = heldShortcut else { continue }
                if heldStaysInRow, AppSwitcher.shared.scrollNavigationActive {
                    if AppSwitcher.shared.navigateFromGesture(columnDelta: direction, rowDelta: 0, staysInRow: true) {
                        haptic()
                    }
                    continue
                }
                let strokes = TrackpadSwitcherKeys.step(shortcut, backward: direction < 0)
                guard !strokes.isEmpty else { continue }
                post(strokes)
                haptic()
            case .row(let direction):
                guard heldShortcut != nil, heldOwnSwitcher, AppSwitcher.shared.scrollNavigationActive else { continue }
                if AppSwitcher.shared.navigateFromGesture(columnDelta: 0, rowDelta: direction,
                                                           staysInRow: heldStaysInRow) {
                    haptic()
                }
            case .finished:
                releaseSwitcher()
            }
        }
    }

    private func ownSwitcherShortcut() -> GlobalShortcut? {
        guard AppFeature.switcher.isAvailable,
              UserDefaults.standard.bool(forKey: DefaultsKey.switcherEnabled) else { return nil }
        return AppSwitcher.shared.gestureShortcut
    }

    var usesOwnSwitcher: Bool { ownSwitcherShortcut() != nil }

    private func releaseSwitcher() {
        guard let shortcut = heldShortcut else { return }
        heldShortcut = nil
        post(TrackpadSwitcherKeys.release(shortcut))
    }

    private func post(_ strokes: [TrackpadSwitcherKeyStroke]) {
        let source = CGEventSource(stateID: .hidSystemState)
        for stroke in strokes {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: stroke.keyCode,
                                      keyDown: stroke.keyDown) else { continue }
            event.flags = stroke.flags
            event.post(tap: .cghidEventTap)
        }
    }

    private func haptic() {
        guard hapticsEnabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    private func handle(_ events: [TrackpadEdgeScrollEvent]) {
        for event in events {
            switch event {
            case .began(let heading):
                guard isRunning else { return }
                beginAutoScroll(heading)
            case .ended:
                stopAutoScroll()
            }
        }
    }

    private func beginAutoScroll(_ heading: TrackpadScrollHeading) {
        stopAutoScroll()
        let now = ProcessInfo.processInfo.systemUptime
        let measured = tapLock.withLock { motion.sign(for: heading, at: now) }
        scrollSign = measured ?? heading.scrollSign(naturalScrolling: Self.naturalScrolling)
        scrollHeading = heading
        scrollStartedAt = now
        lastScrollTick = now
        pacer.reset()
        let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            self?.tickAutoScroll()
        }
        RunLoop.main.add(timer, forMode: .common)
        scrollTimer = timer
        edgeScrolling = true
    }

    private func stopAutoScroll() {
        scrollTimer?.invalidate()
        scrollTimer = nil
        scrollHeading = nil
        pacer.reset()
        if edgeScrolling { edgeScrolling = false }
    }

    private func tickAutoScroll() {
        guard let heading = scrollHeading else { return }
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = now - lastScrollTick
        lastScrollTick = now
        let speed = edgeConfiguration.pointsPerSecond(heldFor: now - scrollStartedAt)
        let pixels = pacer.pixels(pointsPerSecond: speed, elapsed: elapsed, sign: scrollSign)
        guard pixels != 0 else { return }
        postScroll(vertical: heading.isVertical ? pixels : 0, horizontal: heading.isVertical ? 0 : pixels)
    }

    private func postScroll(vertical: Int32, horizontal: Int32) {
        guard let pixels = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
                                   wheel1: vertical, wheel2: horizontal, wheel3: 0) else { return }
        let template = tapLock.withLock { scrollTemplate?.copy() }
        let event = template ?? pixels
        if template != nil {
            for field: CGEventField in [
                .scrollWheelEventDeltaAxis1, .scrollWheelEventDeltaAxis2, .scrollWheelEventDeltaAxis3,
                .scrollWheelEventPointDeltaAxis1, .scrollWheelEventPointDeltaAxis2, .scrollWheelEventPointDeltaAxis3,
            ] {
                event.setIntegerValueField(field, value: pixels.getIntegerValueField(field))
            }
            for field: CGEventField in [
                .scrollWheelEventFixedPtDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis2,
                .scrollWheelEventFixedPtDeltaAxis3,
            ] {
                event.setDoubleValueField(field, value: pixels.getDoubleValueField(field))
            }
            event.timestamp = pixels.timestamp
        }
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event.setIntegerValueField(.scrollWheelEventScrollPhase, value: Int64(CGScrollPhase.changed.rawValue))
        event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: 0)
        event.setIntegerValueField(.eventSourceUserData, value: Self.edgeScrollMarker)
        let target = event.getIntegerValueField(.eventTargetUnixProcessID)
        if template != nil, let pid = pid_t(exactly: target), pid > 0 {
            event.postToPid(pid)
        } else {
            if let location = CGEvent(source: nil)?.location { event.location = location }
            event.post(tap: .cgSessionEventTap)
        }
    }

    private static var naturalScrolling: Bool {
        UserDefaults.standard.object(forKey: "com.apple.swipescrolldirection") == nil
            || UserDefaults.standard.bool(forKey: "com.apple.swipescrolldirection")
    }
}

private func trackpadGestureContactCallback(_ device: UnsafeMutableRawPointer?,
                                            _ touches: UnsafeMutableRawPointer?,
                                            _ count: Int32,
                                            _ timestamp: Double,
                                            _ frame: Int32) -> Int32 {
    TrackpadGestureService.shared.contactFrame(device: device, touches: touches, count: Int(count))
    return 0
}
