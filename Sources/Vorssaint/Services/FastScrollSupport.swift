// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreGraphics
import Foundation

enum FastScrollModifier: String, CaseIterable, Identifiable {
    case option, command, control, fn

    var id: String { rawValue }

    var flag: CGEventFlags {
        switch self {
        case .option: return .maskAlternate
        case .command: return .maskCommand
        case .control: return .maskControl
        case .fn: return .maskSecondaryFn
        }
    }

    var glyph: String {
        switch self {
        case .option: return "⌥"
        case .command: return "⌘"
        case .control: return "⌃"
        case .fn: return "fn"
        }
    }

    var scrollModifier: ScrollHorizontalModifier? {
        ScrollHorizontalModifier(rawValue: rawValue)
    }

    static func sanitized(_ raw: String?) -> FastScrollModifier {
        raw.flatMap(FastScrollModifier.init(rawValue:)) ?? .option
    }
}

struct FastScrollPreferences: Equatable {
    static let multiplierRange = 2...10
    static let defaultMultiplier = 3

    let isEnabled: Bool
    let modifier: FastScrollModifier
    let multiplier: Int
    let mouse: Bool
    let trackpad: Bool

    init(isEnabled: Bool, modifier: FastScrollModifier, multiplier: Int, mouse: Bool, trackpad: Bool) {
        self.isEnabled = isEnabled
        self.modifier = modifier
        self.multiplier = Self.sanitizedMultiplier(multiplier)
        self.mouse = mouse
        self.trackpad = trackpad
    }

    init(defaults: UserDefaults = .standard) {
        func flag(_ key: String) -> Bool { defaults.object(forKey: key) == nil || defaults.bool(forKey: key) }
        self.init(isEnabled: defaults.bool(forKey: AppFeature.fastScroll.availabilityKey)
                    && defaults.bool(forKey: DefaultsKey.fastScrollEnabled),
                  modifier: FastScrollModifier.sanitized(defaults.string(forKey: DefaultsKey.fastScrollModifier)),
                  multiplier: defaults.integer(forKey: DefaultsKey.fastScrollMultiplier),
                  mouse: flag(DefaultsKey.fastScrollMouse),
                  trackpad: flag(DefaultsKey.fastScrollTrackpad))
    }

    var wantsTap: Bool { isEnabled && (mouse || trackpad) }

    static func sanitizedMultiplier(_ value: Int) -> Int {
        guard value != 0 else { return defaultMultiplier }
        return min(max(value, multiplierRange.lowerBound), multiplierRange.upperBound)
    }

    func factor(flags: CGEventFlags, isMouseWheel: Bool) -> Double? {
        guard isEnabled, isMouseWheel ? mouse : trackpad, flags.contains(modifier.flag) else { return nil }
        return Double(multiplier)
    }
}

enum FastScrollSupport {
    @discardableResult
    static func boost(_ event: CGEvent, preferences: FastScrollPreferences, isMouseWheel: Bool) -> Bool {
        guard let factor = preferences.factor(flags: event.flags, isMouseWheel: isMouseWheel) else { return false }
        scale(event, by: factor)
        event.flags.remove(preferences.modifier.flag)
        return true
    }

    static func scale(_ event: CGEvent, by factor: Double) {
        guard factor.isFinite, factor > 0 else { return }
        let verticalLine = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let verticalPoint = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
        let verticalFixed = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        let horizontalLine = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        let horizontalPoint = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)
        let horizontalFixed = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: scaled(verticalLine, factor))
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: scaled(horizontalLine, factor))
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: verticalFixed * factor)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: horizontalFixed * factor)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: scaled(verticalPoint, factor))
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: scaled(horizontalPoint, factor))
    }

    static func scaled(_ value: Int64, _ factor: Double) -> Int64 {
        guard value != 0 else { return 0 }
        let result = (Double(value) * factor).rounded()
        guard result.isFinite else { return value }
        return Int64(min(max(result, -1_000_000), 1_000_000))
    }

    static func conflictingModifiers(_ preferences: FastScrollPreferences,
                                     horizontal: ScrollHorizontalModifier?,
                                     zoom: ScrollHorizontalModifier?) -> Bool {
        guard let mine = preferences.modifier.scrollModifier else { return false }
        return mine == horizontal || mine == zoom
    }
}
