// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Recognizes ⌘C pressed twice in quick succession, which opens the
/// clipboard history without a dedicated shortcut.
struct ClipboardDoubleCopyDetector {
    static let interval: TimeInterval = 0.4

    private var lastCopyAt: TimeInterval?

    mutating func register(isCommandC: Bool, isRepeat: Bool, at timestamp: TimeInterval) -> Bool {
        guard isCommandC else {
            lastCopyAt = nil
            return false
        }
        guard !isRepeat else { return false }
        if let lastCopyAt, timestamp >= lastCopyAt, timestamp - lastCopyAt <= Self.interval {
            self.lastCopyAt = nil
            return true
        }
        lastCopyAt = timestamp
        return false
    }

    mutating func reset() {
        lastCopyAt = nil
    }
}
