// SPDX-License-Identifier: GPL-3.0-only

import ApplicationServices
import Foundation

/// Replaces real keyboard/trackpad Space switches with a native Dock swipe
/// whose velocity is controlled by the user.
/// Technique adapted from jurplel/InstantSpaceSwitcher (MIT License).
final class HotkeyEngine: @unchecked Sendable {
    enum Direction { case left, right }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var swipeTracking = false
    private var swipeFired = false
    private(set) var isRunning = false
    var velocity: Double = 60

    func start() -> Bool {
        guard !isRunning else { return true }
        let mask = CGEventMask(1) << CGEventType.keyDown.rawValue
            | CGEventMask(1) << CGEventType.keyUp.rawValue
            | CGEventMask(1) << 29
            | CGEventMask(1) << 30
        let context = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let engine = Unmanaged<HotkeyEngine>.fromOpaque(context).takeUnretainedValue()
                return engine.handle(type: type, event: event)
            },
            userInfo: context
        ) else { return false }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return false
        }
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isRunning = true
        return true
    }

    func stop() {
        swipeTracking = false
        swipeFired = false
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: false) }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CFRunLoopSourceInvalidate(runLoopSource)
        }
        if let eventTap { CFMachPortInvalidate(eventTap) }
        runLoopSource = nil
        eventTap = nil
        isRunning = false
    }

    func switchSpace(_ direction: Direction) {
        let sign = direction == .right ? 1.0 : -1.0
        postSwipe(phase: 1, sign: sign)
        postSwipe(phase: 2, sign: sign)
        postSwipe(phase: 4, sign: sign)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown || type == .keyUp {
            let flags = event.flags
            let hasControl = flags.contains(.maskControl)
            let hasOtherModifiers = flags.contains(.maskCommand)
                || flags.contains(.maskAlternate) || flags.contains(.maskShift)
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            guard hasControl, !hasOtherModifiers, keyCode == 123 || keyCode == 124 else {
                return Unmanaged.passUnretained(event)
            }
            if type == .keyDown { switchSpace(keyCode == 123 ? .left : .right) }
            return nil
        }

        let internalType = event.getIntegerValueField(Self.eventTypeField)
        guard internalType == 29 || internalType == 30 else {
            return Unmanaged.passUnretained(event)
        }

        // Synthetic gestures have a process ID; physical HID gestures do not.
        if event.getIntegerValueField(.eventSourceUnixProcessID) != 0 {
            return Unmanaged.passUnretained(event)
        }

        if internalType == 30 {
            guard event.getIntegerValueField(Self.gestureHIDType) == 23,
                  event.getIntegerValueField(Self.swipeMotion) == 1 else {
                return Unmanaged.passUnretained(event)
            }
            switch event.getIntegerValueField(Self.gesturePhase) {
            case 1:
                swipeTracking = true
                swipeFired = false
                return nil
            case 2:
                if swipeTracking && !swipeFired {
                    let progress = event.getDoubleValueField(Self.swipeProgress)
                    if progress != 0 {
                        swipeFired = true
                        switchSpace(progress > 0 ? .right : .left)
                    }
                }
                return swipeTracking ? nil : Unmanaged.passUnretained(event)
            case 4:
                if swipeTracking && !swipeFired {
                    let originalVelocity = event.getDoubleValueField(Self.swipeVelocityX)
                    if originalVelocity != 0 {
                        swipeFired = true
                        switchSpace(originalVelocity > 0 ? .right : .left)
                    }
                }
                swipeTracking = false
                swipeFired = false
                return nil
            case 8:
                swipeTracking = false
                swipeFired = false
                return nil
            default:
                return swipeTracking ? nil : Unmanaged.passUnretained(event)
            }
        }

        return swipeTracking ? nil : Unmanaged.passUnretained(event)
    }

    private func postSwipe(phase: Int64, sign: Double) {
        guard let event = CGEvent(source: nil) else { return }
        event.setIntegerValueField(Self.eventTypeField, value: 30)
        event.setIntegerValueField(Self.gestureHIDType, value: 23)
        event.setIntegerValueField(Self.gesturePhase, value: phase)
        event.setDoubleValueField(Self.swipeProgress, value: sign * Double(Float.leastNonzeroMagnitude))
        event.setIntegerValueField(Self.swipeMotion, value: 1)
        event.setDoubleValueField(Self.swipeVelocityX, value: sign * velocity)
        event.setDoubleValueField(Self.swipeVelocityY, value: sign * velocity)
        event.post(tap: .cgSessionEventTap)
    }

    private static let eventTypeField = CGEventField(rawValue: 55)!
    private static let gestureHIDType = CGEventField(rawValue: 110)!
    private static let swipeMotion = CGEventField(rawValue: 123)!
    private static let swipeProgress = CGEventField(rawValue: 124)!
    private static let swipeVelocityX = CGEventField(rawValue: 129)!
    private static let swipeVelocityY = CGEventField(rawValue: 130)!
    private static let gesturePhase = CGEventField(rawValue: 132)!
}
