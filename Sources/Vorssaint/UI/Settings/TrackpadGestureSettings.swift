// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

struct TrackpadGestureSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var service = TrackpadGestureService.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @AppStorage(DefaultsKey.trackpadAppSwipeEnabled) private var appSwipeEnabled = false
    @AppStorage(DefaultsKey.trackpadAppSwipeFingers) private var fingersRaw = TrackpadSwipeFingers.three.rawValue
    @AppStorage(DefaultsKey.trackpadAppSwipeStepDistance) private var stepDistance =
        TrackpadAppSwipeConfiguration.defaultStepDistance
    @AppStorage(DefaultsKey.trackpadAppSwipeExclusive) private var exclusive = true
    @AppStorage(DefaultsKey.trackpadAppSwipeReversed) private var reversed = false
    @AppStorage(DefaultsKey.trackpadAppSwipeHaptics) private var haptics = true
    @AppStorage(DefaultsKey.trackpadAppSwipeEngageDistance) private var engageDistance =
        TrackpadAppSwipeConfiguration.defaultEngageDistance
    @AppStorage(DefaultsKey.switcherSwipeFollowsFingers) private var switcherFollowsFingers = true
    @AppStorage(DefaultsKey.switcherSwipeVertical) private var switcherVertical = false
    @AppStorage(DefaultsKey.switcherSwipeStaysInRow) private var switcherStaysInRow = true
    @AppStorage(DefaultsKey.trackpadEdgeScrollEnabled) private var edgeScrollEnabled = false
    @AppStorage(DefaultsKey.trackpadEdgeScrollZone) private var edgeZone = TrackpadEdgeScrollConfiguration.defaultEdgeZone
    @AppStorage(DefaultsKey.trackpadEdgeScrollSpeed) private var speedRaw = TrackpadEdgeScrollSpeed.normal.rawValue
    @AppStorage(DefaultsKey.trackpadEdgeScrollAccelerates) private var accelerates = true
    @AppStorage(DefaultsKey.trackpadEdgeScrollHorizontal) private var horizontal = true

    private static let trackpadSettingsURL = URL(string: "x-apple.systempreferences:com.apple.Trackpad-Settings.extension")
    private static let pointerSettingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess?Mouse")

    private var text: TrackpadGestureStrings { FeatureStrings.trackpadGestures(l10n.language) }

    private var anyEnabled: Bool { appSwipeEnabled || edgeScrollEnabled }

    var body: some View {
        Form {
            Section(text.pageTitle) {
                Text(text.hubDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                status
            }

            Section(text.appSwipeSection) {
                VStack(alignment: .leading, spacing: 2) {
                    Toggle(text.appSwipeToggle, isOn: $appSwipeEnabled)
                        .onChange(of: appSwipeEnabled) { _, value in enabledChanged(value) }
                    Text(text.appSwipeCaption(fingers: fingers.rawValue))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(Array(conflicts.enumerated()), id: \.offset) { _, conflict in
                    conflictRow(conflict)
                }
                Group {
                    Picker(text.fingersLabel, selection: fingersBinding) {
                        ForEach(TrackpadSwipeFingers.allCases) { option in
                            Text(text.name(option)).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    captionedToggle(text.exclusiveToggle(fingers: fingers.rawValue), caption: text.exclusiveCaption,
                                    isOn: $exclusive)
                    distanceSlider(text.engageLabel, caption: text.engageCaption,
                                   value: engageDistanceBinding,
                                   range: TrackpadAppSwipeConfiguration.engageDistanceRange,
                                   readout: TrackpadAppSwipeConfiguration.sanitizedEngageDistance(engageDistance))
                    distanceSlider(text.sensitivityLabel, caption: text.stepCaption,
                                   value: stepDistanceBinding,
                                   range: TrackpadAppSwipeConfiguration.stepDistanceRange,
                                   readout: TrackpadAppSwipeConfiguration.sanitizedStepDistance(stepDistance))
                    captionedToggle(text.reversedToggle, caption: text.reversedCaption, isOn: $reversed)
                    captionedToggle(text.hapticsToggle, caption: text.hapticsCaption, isOn: $haptics)
                    Label(service.usesOwnSwitcher ? text.targetOwnSwitcher : text.targetSystemSwitcher,
                          systemImage: "rectangle.on.rectangle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .disabled(!appSwipeEnabled)
            }

            if AppFeature.switcher.isAvailable {
                Section(text.switcherSwipeSection) {
                    captionedToggle(text.switcherFollowToggle, caption: text.switcherFollowCaption,
                                    isOn: $switcherFollowsFingers)
                    captionedToggle(text.switcherVerticalToggle, caption: text.switcherVerticalCaption,
                                    isOn: $switcherVertical)
                    captionedToggle(text.staysInRowToggle, caption: text.staysInRowCaption,
                                    isOn: $switcherStaysInRow)
                        .disabled(!switcherVertical)
                }
            }

            Section(text.edgeScrollSection) {
                VStack(alignment: .leading, spacing: 2) {
                    Toggle(text.edgeScrollToggle, isOn: $edgeScrollEnabled)
                        .onChange(of: edgeScrollEnabled) { _, value in enabledChanged(value) }
                    Text(text.edgeScrollCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Group {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(text.edgeZoneLabel)
                            Spacer()
                            Text("\(Int((TrackpadEdgeScrollConfiguration.sanitizedEdgeZone(edgeZone) * 100).rounded()))%")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: edgeZoneBinding, in: TrackpadEdgeScrollConfiguration.edgeZoneRange, step: 0.01)
                        Text(text.edgeZoneCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Picker(text.speedLabel, selection: speedBinding) {
                        ForEach(TrackpadEdgeScrollSpeed.allCases) { option in
                            Text(text.name(option)).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    captionedToggle(text.acceleratesToggle, caption: text.acceleratesCaption, isOn: $accelerates)
                    Toggle(text.horizontalToggle, isOn: $horizontal)
                        .onChange(of: horizontal) { _, _ in resync() }
                }
                .disabled(!edgeScrollEnabled)
            }

            if anyEnabled, !permissions.accessibility {
                Section(l10n.s.permissionRequired) {
                    PermissionRow(kind: .accessibility)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { service.refreshSystemGestures() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            service.refreshSystemGestures()
        }
    }

    @ViewBuilder
    private var status: some View {
        if anyEnabled, service.touchDeviceMissing {
            Label(text.noTrackpad, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        } else if anyEnabled, service.isRunning {
            Label(text.activeNow, systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        }
    }

    private var fingers: TrackpadSwipeFingers {
        _ = features.revision
        return TrackpadSwipeFingers.sanitized(fingersRaw)
    }

    private var conflicts: [TrackpadSwipeConflict] {
        appSwipeEnabled ? service.systemGestures.conflicts(for: fingers) : []
    }

    private func conflictRow(_ conflict: TrackpadSwipeConflict) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(text.conflict(conflict), systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            Button(conflict == .threeFingerDrag ? text.openPointerSettings : text.openTrackpadSettings) {
                let url = conflict == .threeFingerDrag ? Self.pointerSettingsURL : Self.trackpadSettingsURL
                if let url { NSWorkspace.shared.open(url) }
            }
            .controlSize(.small)
        }
    }

    private func captionedToggle(_ title: String, caption: String, isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(title, isOn: isOn)
                .onChange(of: isOn.wrappedValue) { _, _ in resync() }
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var fingersBinding: Binding<TrackpadSwipeFingers> {
        Binding {
            TrackpadSwipeFingers.sanitized(fingersRaw)
        } set: { value in
            fingersRaw = value.rawValue
            resync()
        }
    }

    private var stepDistanceBinding: Binding<Double> {
        Binding {
            TrackpadAppSwipeConfiguration.sanitizedStepDistance(stepDistance)
        } set: { value in
            stepDistance = TrackpadAppSwipeConfiguration.sanitizedStepDistance(value)
            resync()
        }
    }

    private func distanceSlider(_ title: String, caption: String, value: Binding<Double>,
                                range: ClosedRange<Double>, readout: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int((readout * 100).rounded()))%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: 0.005)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var speedBinding: Binding<TrackpadEdgeScrollSpeed> {
        Binding {
            TrackpadEdgeScrollSpeed.sanitized(speedRaw)
        } set: { value in
            speedRaw = value.rawValue
            resync()
        }
    }

    private var engageDistanceBinding: Binding<Double> {
        Binding {
            TrackpadAppSwipeConfiguration.sanitizedEngageDistance(engageDistance)
        } set: { value in
            engageDistance = TrackpadAppSwipeConfiguration.sanitizedEngageDistance(value)
            resync()
        }
    }

    private var edgeZoneBinding: Binding<Double> {
        Binding {
            TrackpadEdgeScrollConfiguration.sanitizedEdgeZone(edgeZone)
        } set: { value in
            edgeZone = TrackpadEdgeScrollConfiguration.sanitizedEdgeZone(value)
            resync()
        }
    }

    private func enabledChanged(_ value: Bool) {
        resync()
        guard value, !permissions.accessibility else { return }
        permissions.requestAccessibility()
        permissions.openAccessibilitySettings()
    }

    private func resync() {
        TrackpadGestureService.shared.syncWithPreferences()
    }
}
