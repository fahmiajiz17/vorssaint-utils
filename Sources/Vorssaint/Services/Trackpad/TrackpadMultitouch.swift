// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import CoreFoundation
import Darwin

enum TrackpadMultitouch {
    typealias ContactCallback = @convention(c) (
        UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32
    ) -> Int32
    private typealias CreateListFn = @convention(c) () -> Unmanaged<CFArray>?
    private typealias RegisterFn = @convention(c) (UnsafeMutableRawPointer, ContactCallback?) -> Void
    private typealias StartFn = @convention(c) (UnsafeMutableRawPointer, Int32) -> Void
    private typealias StopFn = @convention(c) (UnsafeMutableRawPointer) -> Void
    private typealias FamilyFn = @convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<Int32>) -> Int32

    private static let handle: UnsafeMutableRawPointer? = dlopen(
        "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport",
        RTLD_NOW
    )

    private static let createListFn: CreateListFn? = symbol("MTDeviceCreateList")
    private static let registerFn: RegisterFn? = symbol("MTRegisterContactFrameCallback")
    private static let unregisterFn: RegisterFn? = symbol("MTUnregisterContactFrameCallback")
    private static let startFn: StartFn? = symbol("MTDeviceStart")
    private static let stopFn: StopFn? = symbol("MTDeviceStop")
    private static let familyFn: FamilyFn? = symbol("MTDeviceGetFamilyID")

    private static let magicMouseFamilies: Set<Int32> = [112, 113]
    private static let touchStride = 96
    private static let identifierOffset = 16
    private static let stateOffset = 20
    private static let positionXOffset = 32
    private static let positionYOffset = 36
    private static let contactStates: ClosedRange<Int32> = 3...4

    static var available: Bool {
        createListFn != nil && registerFn != nil && unregisterFn != nil && startFn != nil && stopFn != nil
    }

    static func deviceList() -> CFArray? {
        guard let createListFn else { return nil }
        let list = createListFn()?.takeRetainedValue()
        guard let list, CFArrayGetCount(list) > 0 else { return nil }
        return list
    }

    static func isTrackpad(_ device: UnsafeMutableRawPointer) -> Bool {
        guard let familyFn else { return true }
        var family: Int32 = 0
        guard familyFn(device, &family) == 0 else { return true }
        return !magicMouseFamilies.contains(family)
    }

    static func register(_ device: UnsafeMutableRawPointer, _ callback: ContactCallback) {
        registerFn?(device, callback)
    }

    static func unregister(_ device: UnsafeMutableRawPointer, _ callback: ContactCallback) {
        unregisterFn?(device, callback)
    }

    static func start(_ device: UnsafeMutableRawPointer) {
        startFn?(device, 0)
    }

    static func stop(_ device: UnsafeMutableRawPointer) {
        stopFn?(device)
    }

    static func contacts(touches: UnsafeMutableRawPointer?, count: Int) -> [TrackpadContact]? {
        guard count > 0 else { return [] }
        guard let touches, count <= 20 else { return nil }
        var contacts: [TrackpadContact] = []
        contacts.reserveCapacity(count)
        for index in 0..<count {
            let base = touches.advanced(by: index * touchStride)
            let state = base.loadUnaligned(fromByteOffset: stateOffset, as: Int32.self)
            guard (0...7).contains(state) else { return nil }
            guard contactStates.contains(state) else { continue }
            let x = base.loadUnaligned(fromByteOffset: positionXOffset, as: Float.self)
            let y = base.loadUnaligned(fromByteOffset: positionYOffset, as: Float.self)
            guard x.isFinite, y.isFinite, x >= -0.2, x <= 1.2, y >= -0.2, y <= 1.2 else { return nil }
            let identifier = base.loadUnaligned(fromByteOffset: identifierOffset, as: Int32.self)
            contacts.append(TrackpadContact(id: identifier, x: min(max(x, 0), 1), y: min(max(y, 0), 1)))
        }
        return contacts
    }

    private static func symbol<T>(_ name: String) -> T? {
        guard let handle, let raw = dlsym(handle, name) else { return nil }
        return unsafeBitCast(raw, to: T.self)
    }
}
