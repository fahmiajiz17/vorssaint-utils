// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum ClipboardDoubleCopyTests {
    static func run(_ suite: TestSuite) {
        var detector = ClipboardDoubleCopyDetector()
        suite.expect(!detector.register(isCommandC: true, isRepeat: false, at: 10),
                     "a single copy does not open the history")
        suite.expect(detector.register(isCommandC: true, isRepeat: false, at: 10.25),
                     "two quick copies open the history")
        suite.expect(!detector.register(isCommandC: true, isRepeat: false, at: 10.4),
                     "a third copy starts a new pair")

        var slow = ClipboardDoubleCopyDetector()
        _ = slow.register(isCommandC: true, isRepeat: false, at: 20)
        suite.expect(!slow.register(isCommandC: true, isRepeat: false, at: 20.6),
                     "copies far apart stay ordinary copies")
        suite.expect(slow.register(isCommandC: true, isRepeat: false, at: 20.9),
                     "the later copy still pairs with the next one")

        var interrupted = ClipboardDoubleCopyDetector()
        _ = interrupted.register(isCommandC: true, isRepeat: false, at: 30)
        _ = interrupted.register(isCommandC: false, isRepeat: false, at: 30.1)
        suite.expect(!interrupted.register(isCommandC: true, isRepeat: false, at: 30.2),
                     "another key between copies cancels the pair")

        var held = ClipboardDoubleCopyDetector()
        _ = held.register(isCommandC: true, isRepeat: false, at: 40)
        suite.expect(!held.register(isCommandC: true, isRepeat: true, at: 40.1),
                     "holding the key down does not count as a second press")
        suite.expect(held.register(isCommandC: true, isRepeat: false, at: 40.3),
                     "a real second press after a repeat still opens the history")
    }
}
