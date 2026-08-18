// SPDX-License-Identifier: GPL-3.0-only

import ApplicationServices
import AppKit
import Foundation

@MainActor
final class MotionController: ObservableObject {
    @Published var speed: Double {
        didSet {
            engine.velocity = speed
            storage.set(speed, forKey: speedKey)
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
        speed = savedSpeed == 0 ? 60 : savedSpeed
        isEnabled = storage.object(forKey: enabledKey) as? Bool ?? true
        engine.velocity = speed
        refreshPermission()
        configureEngine()
    }

    var approximateMultiplier: String {
        String(format: "%.1f×", speed / 40)
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

    func setPreset(_ velocity: Double) {
        speed = velocity
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

        engine.velocity = speed
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
