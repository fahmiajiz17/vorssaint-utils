// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

enum FastScrollTests {
    static func run(_ suite: TestSuite) {
        preferences(suite)
        boostsWheel(suite)
        boostsTrackpad(suite)
        leavesOthersAlone(suite)
        conflicts(suite)
        catalog(suite)
    }

    private static func enabled(modifier: FastScrollModifier = .option, multiplier: Int = 3,
                                mouse: Bool = true, trackpad: Bool = true) -> FastScrollPreferences {
        FastScrollPreferences(isEnabled: true, modifier: modifier, multiplier: multiplier,
                              mouse: mouse, trackpad: trackpad)
    }

    private static func wheel(line: Int32, flags: CGEventFlags) -> CGEvent {
        let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1,
                            wheel1: line, wheel2: 0, wheel3: 0)!
        event.flags = flags
        return event
    }

    private static func trackpad(points: Int32, flags: CGEventFlags) -> CGEvent {
        let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
                            wheel1: points, wheel2: 0, wheel3: 0)!
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event.setIntegerValueField(.scrollWheelEventScrollPhase, value: Int64(CGScrollPhase.changed.rawValue))
        event.flags = flags
        return event
    }

    private static func preferences(_ suite: TestSuite) {
        let name = "com.vorssaint.tests.fast-scroll.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        suite.expect(!FastScrollPreferences(defaults: defaults).isEnabled,
                     "fast scrolling is off until installed and switched on")
        defaults.set(true, forKey: AppFeature.fastScroll.availabilityKey)
        defaults.set(true, forKey: DefaultsKey.fastScrollEnabled)
        let loaded = FastScrollPreferences(defaults: defaults)
        suite.expect(loaded.isEnabled && loaded.modifier == .option && loaded.multiplier == 3
                && loaded.mouse && loaded.trackpad && loaded.wantsTap,
                     "switched on, Option triples the mouse wheel and the trackpad")
        defaults.set(false, forKey: AppFeature.fastScroll.availabilityKey)
        suite.expect(!FastScrollPreferences(defaults: defaults).isEnabled,
                     "uninstalling the feature turns the boost off even with its switch left on")
        suite.expect(FastScrollPreferences.sanitizedMultiplier(0) == 3
                && FastScrollPreferences.sanitizedMultiplier(99) == 10
                && FastScrollPreferences.sanitizedMultiplier(1) == 2,
                     "the multiplier stays between two and ten")
        suite.expect(FastScrollModifier.sanitized("bogus") == .option, "an unknown key falls back to Option")
    }

    private static func boostsWheel(_ suite: TestSuite) {
        let event = wheel(line: -2, flags: .maskAlternate)
        let point = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
        let fixed = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        let boosted = FastScrollSupport.boost(event, preferences: enabled(), isMouseWheel: true)
        suite.expect(boosted
                && event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == -6
                && event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == point * 3
                && abs(event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1) - fixed * 3) < 0.001,
                     "Option makes a wheel notch travel three times as far in every field")
        suite.expect(!event.flags.contains(.maskAlternate),
                     "the held key is taken off so the app does not treat it as Option-scroll")
        let fast = wheel(line: 1, flags: [.maskCommand])
        FastScrollSupport.boost(fast, preferences: enabled(modifier: .command, multiplier: 10), isMouseWheel: true)
        suite.expect(fast.getIntegerValueField(.scrollWheelEventDeltaAxis1) == 10,
                     "the chosen key and multiplier are honored")
    }

    private static func boostsTrackpad(_ suite: TestSuite) {
        let event = trackpad(points: 12, flags: .maskAlternate)
        FastScrollSupport.boost(event, preferences: enabled(), isMouseWheel: false)
        suite.expect(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == 36,
                     "the trackpad scrolls three times as far with Option held")
        let mouseOnly = trackpad(points: 12, flags: .maskAlternate)
        let skipped = FastScrollSupport.boost(mouseOnly, preferences: enabled(trackpad: false), isMouseWheel: false)
        suite.expect(!skipped && mouseOnly.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == 12
                && mouseOnly.flags.contains(.maskAlternate),
                     "with the trackpad turned off its scrolling is left as it is")
    }

    private static func leavesOthersAlone(_ suite: TestSuite) {
        let plain = wheel(line: -2, flags: [])
        suite.expect(!FastScrollSupport.boost(plain, preferences: enabled(), isMouseWheel: true)
                && plain.getIntegerValueField(.scrollWheelEventDeltaAxis1) == -2,
                     "without the key the wheel scrolls normally")
        let off = FastScrollPreferences(isEnabled: false, modifier: .option, multiplier: 5, mouse: true, trackpad: true)
        let held = wheel(line: -2, flags: .maskAlternate)
        suite.expect(!FastScrollSupport.boost(held, preferences: off, isMouseWheel: true)
                && held.flags.contains(.maskAlternate),
                     "switched off, Option-scroll reaches the app untouched")
        let shifted = wheel(line: 1, flags: [.maskAlternate, .maskShift])
        FastScrollSupport.boost(shifted, preferences: enabled(), isMouseWheel: true)
        suite.expect(shifted.flags.contains(.maskShift) && !shifted.flags.contains(.maskAlternate)
                && shifted.getIntegerValueField(.scrollWheelEventDeltaAxis1) == 3,
                     "Shift stays on a boosted tick, so fast horizontal scrolling still works")
        suite.expect(FastScrollSupport.scaled(0, 3) == 0 && FastScrollSupport.scaled(Int64.max, 3) == 1_000_000,
                     "scaling never invents movement or overflows")
    }

    private static func conflicts(_ suite: TestSuite) {
        suite.expect(FastScrollSupport.conflictingModifiers(enabled(), horizontal: .option, zoom: nil),
                     "Option for horizontal scrolling clashes with Option for fast scrolling")
        suite.expect(!FastScrollSupport.conflictingModifiers(enabled(), horizontal: .shift, zoom: .control),
                     "the default Shift and Control choices leave Option free")
        suite.expect(!FastScrollSupport.conflictingModifiers(enabled(modifier: .fn), horizontal: .option, zoom: .command),
                     "Fn is never used by the other wheel shortcuts")
    }

    private static func catalog(_ suite: TestSuite) {
        let feature = AppFeature.fastScroll
        suite.expect(feature.group == .mouseKeyboard && feature.permissions == [.accessibility]
                && feature.enabledKeys == [DefaultsKey.fastScrollEnabled] && !feature.installedByDefault
                && feature.settingsDestination == FeatureSettingsDestination(.mouse, sectionAnchor: .fastScroll),
                     "fast scrolling lives on the Mouse page, needs Accessibility and is opt-in")
        let registered = Defaults.registeredDefaults
        suite.expect(registered[DefaultsKey.fastScrollEnabled] as? Bool == false
                && registered[DefaultsKey.fastScrollModifier] as? String == "option"
                && registered[DefaultsKey.fastScrollMultiplier] as? Int == 3
                && registered[DefaultsKey.fastScrollMouse] as? Bool == true
                && registered[DefaultsKey.fastScrollTrackpad] as? Bool == true,
                     "fast scrolling defaults to Option at three times on both mouse and trackpad")
        for language in AppLanguage.allCases {
            let strings = FeatureStrings.fastScroll(language)
            suite.expect(!strings.title.isEmpty && FastScrollModifier.allCases.allSatisfy { !strings.name($0).isEmpty }
                    && strings.panelCaption(.option).contains("⌥"),
                         "fast scroll strings are complete in \(language.rawValue)")
        }
    }
}
