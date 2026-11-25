// SPDX-License-Identifier: GPL-3.0-only

import ApplicationServices
import AppKit
import Foundation

/// Named Space-switching speeds. Each level sets the release velocity passed
/// to Dock and, on macOS 27, the accelerating ramp that precedes the release.
/// Fast and Instant match the former 1× and 2.5× presets;
/// Smooth and Balanced add calmer transitions below them.
enum SpeedLevel: Int, CaseIterable, Identifiable {
    case smooth, balanced, fast, instant

    static let defaultLevel: SpeedLevel = .fast

    var id: Int { rawValue }

    var velocity: Double {
        switch self {
        case .smooth: 10
        case .balanced: 20
        case .fast: 42
        case .instant: 100
        }
    }

    var title: String {
        switch self {
        case .smooth: "Smooth"
        case .balanced: "Balanced"
        case .fast: "Fast"
        case .instant: "Instant"
        }
    }

    /// Duration of the accelerating ramp before release, in seconds.
    /// Zero releases immediately.
    var rampDuration: Double {
        switch self {
        case .smooth: 0.12
        case .balanced: 0.08
        case .fast: 0.04
        case .instant: 0
        }
    }

    /// Ramp curve exponent: progress = t^power. Higher values hold the Space
    /// back longer and push it harder towards the end.
    var rampPower: Double {
        switch self {
        case .smooth: 1
        case .balanced: 2
        case .fast: 4
        case .instant: 6
        }
    }

    /// Maps any stored velocity (including values from the old 40–100 slider)
    /// to the closest named level.
    static func nearest(to velocity: Double) -> SpeedLevel {
        allCases.min { abs($0.velocity - velocity) < abs($1.velocity - velocity) } ?? defaultLevel
    }
}

@MainActor
final class MotionController: ObservableObject {
    @Published var speedLevel: SpeedLevel {
        didSet {
            engine.apply(speedLevel)
            storage.set(speedLevel.velocity, forKey: speedKey)
        }
    }
    @Published var isEnabled: Bool {
        didSet {
            storage.set(isEnabled, forKey: enabledKey)
            configureEngine()
        }
    }
    @Published private(set) var hasAccessibilityPermission = false
    @Published private(set) var isRunning = false
    @Published private(set) var message = "Starting…"

    private let engine = HotkeyEngine()
    private let storage = UserDefaults.standard
    private let speedKey = "gestureVelocity"
    private let enabledKey = "acceleratorEnabled"
    private var permissionTimer: Timer?

    init() {
        let savedSpeed = storage.double(forKey: speedKey)
        speedLevel = savedSpeed == 0 ? .defaultLevel : .nearest(to: savedSpeed)
        isEnabled = storage.object(forKey: enabledKey) as? Bool ?? true
        engine.apply(speedLevel)
        refreshPermission()
        configureEngine()
    }

    func requestAccessibilityPermission() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        message = "Allow SpaceShift, then return here"
        startPermissionPolling()
    }

    func refreshPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
        configureEngine()
    }

    func testRight() {
        guard isRunning else { return }
        engine.switchSpace(.right)
    }

    private func configureEngine() {
        guard isEnabled else {
            engine.stop()
            isRunning = false
            message = "Paused"
            return
        }
        guard hasAccessibilityPermission else {
            engine.stop()
            isRunning = false
            message = "Accessibility permission required"
            return
        }

        engine.apply(speedLevel)
        isRunning = engine.start()
        message = isRunning ? "Keyboard + trackpad acceleration active" : "Event interception failed"
    }

    private func startPermissionPolling() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard AXIsProcessTrusted() else { return }
            timer.invalidate()
            Task { @MainActor in
                self?.refreshPermission()
            }
        }
    }
}
