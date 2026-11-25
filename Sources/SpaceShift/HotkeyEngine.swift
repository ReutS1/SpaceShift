// SPDX-License-Identifier: GPL-3.0-only

import AppKit
import ApplicationServices
import Foundation
import QuartzCore

/// Calls back on every display refresh (CADisplayLink needs an @objc target).
private final class DisplayLinkTarget: NSObject, @unchecked Sendable {
    let onFrame: () -> Void
    init(onFrame: @escaping () -> Void) { self.onFrame = onFrame }
    @objc func frame(_ link: CADisplayLink) { onFrame() }
}

/// Replaces real keyboard/trackpad Space switches with a native Dock swipe
/// whose velocity is controlled by the user.
/// Technique adapted from jurplel/InstantSpaceSwitcher (MIT License).
/// macOS 27 IOHID payload based on joshuarli/iss (0BSD License).
final class HotkeyEngine: @unchecked Sendable {
    enum Direction { case left, right }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var swipeTracking = false
    private var swipeFired = false
    private(set) var isRunning = false
    private(set) var velocity: Double = 60
    private(set) var rampDuration: Double = 0
    private(set) var rampPower: Double = 1

    /// Synthetic macOS 27 swipes begin almost at rest. Starting at a full
    /// Space made Dock jump before it animated.
    private static let softStartProgress = 0.001
    private var rampLink: CADisplayLink?
    private var rampDirection: Direction?
    private var deferredPhysicalEnd: CGEvent?
    /// Marks events SpaceShift re-posts so its own tap lets them through.
    private static let repostMarker: Int64 = 0x5353_4846

    private var requiresIOHIDPayload: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
    }

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

    func apply(_ level: SpeedLevel) {
        velocity = level.velocity
        rampDuration = level.rampDuration
        rampPower = level.rampPower
    }

    func stop() {
        finishRamp()
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
        if requiresIOHIDPayload {
            if rampDuration > 0 {
                startRamp(direction)
            } else {
                postAugmentedSwipe(direction)
            }
            return
        }

        let sign = direction == .right ? 1.0 : -1.0
        postSwipe(phase: 1, sign: sign)
        postSwipe(phase: 2, sign: sign)
        postSwipe(phase: 4, sign: sign)
    }

    // MARK: Accelerating ramp (macOS 27)

    /// Begins a swipe, then advances its progress once per display frame
    /// along t^power for `rampDuration`, and releases it at `velocity`.
    /// Frame-synced updates keep Dock's tracking smooth.
    private func startRamp(_ direction: Direction) {
        finishRamp()
        guard postAugmentedEvent(phase: 1, direction: direction, progress: Self.softStartProgress, velocity: 0) else { return }
        rampDirection = direction

        let start = CACurrentMediaTime()
        let duration = rampDuration
        let power = max(1, rampPower)
        let target = DisplayLinkTarget { [weak self] in
            guard let self, self.rampDirection == direction else { return }
            let t = min(1, (CACurrentMediaTime() - start) / duration)
            let progress = Self.softStartProgress + (1 - Self.softStartProgress) * pow(t, power)
            self.postAugmentedEvent(phase: 2, direction: direction, progress: progress, velocity: 0)
            if t >= 1 { self.finishRamp() }
        }
        // The tap callback and the display link both run on the main thread.
        let started = MainActor.assumeIsolated {
            guard let screen = NSScreen.main ?? NSScreen.screens.first else { return false }
            let link = screen.displayLink(target: target, selector: #selector(DisplayLinkTarget.frame(_:)))
            link.add(to: .main, forMode: .common)
            self.rampLink = link
            return true
        }
        if !started { finishRamp() }
    }

    /// Releases the in-flight ramp (if any) at full progress with the
    /// selected velocity, then replays a deferred physical gesture end.
    private func finishRamp() {
        rampLink?.invalidate()
        rampLink = nil
        if let direction = rampDirection {
            rampDirection = nil
            postAugmentedEvent(phase: 4, direction: direction, progress: 1, velocity: velocity)
        }
        if let deferred = deferredPhysicalEnd {
            deferredPhysicalEnd = nil
            deferred.setIntegerValueField(.eventSourceUserData, value: Self.repostMarker)
            deferred.post(tap: .cgSessionEventTap)
        }
    }

    /// Posts one macOS 27 Dock swipe event. `progress` is 0...1; the
    /// direction sign is applied here.
    @discardableResult
    private func postAugmentedEvent(phase: Int64, direction: Direction, progress: Double, velocity: Double) -> Bool {
        guard let event = makeAugmentedSwipeEvent(
            phase: phase, sign: Self.augmentedSign(direction), progress: progress, endVelocity: velocity
        ), let augmented = augmentWithIOHIDPayload(event) else { return false }
        postPair(dockEvent: augmented)
        return true
    }

    /// Direction is reversed in the macOS 27 Dock gesture path.
    private static func augmentedSign(_ direction: Direction) -> Double {
        direction == .right ? -1.0 : 1.0
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

        if event.getIntegerValueField(.eventSourceUserData) == Self.repostMarker {
            return Unmanaged.passUnretained(event)
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
                        switchSpace(physicalDirection(for: progress))
                    }
                }
                return swipeTracking ? nil : Unmanaged.passUnretained(event)
            case 4:
                let wasTracking = swipeTracking
                if swipeTracking && !swipeFired {
                    let originalVelocity = event.getDoubleValueField(Self.swipeVelocityX)
                    if originalVelocity != 0 {
                        swipeFired = true
                        switchSpace(physicalDirection(for: originalVelocity))
                    }
                }
                swipeTracking = false
                swipeFired = false

                // macOS 27 needs the real terminal event to reach Dock so it
                // can close the physical gesture state after our replacement.
                if requiresIOHIDPayload && wasTracking {
                    event.setDoubleValueField(Self.swipeVelocityX, value: 0)
                    event.setDoubleValueField(Self.swipeVelocityY, value: 0)
                    event.setDoubleValueField(Self.swipeProgress, value: 0)
                    // Don't let the physical end cut a ramp short;
                    // replay it once the ramp finishes.
                    if rampLink != nil, let copy = event.copy() {
                        deferredPhysicalEnd = copy
                        return nil
                    }
                    return Unmanaged.passUnretained(event)
                }
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

    private func physicalDirection(for value: Double) -> Direction {
        return value > 0 ? .right : .left
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

    /// macOS 27 validates Dock swipes against the raw IOHID event embedded in
    /// serialized CGEvent field 4205. Build the complete sequence first so a
    /// serialization failure cannot leave Dock in a partial gesture state.
    private func postAugmentedSwipe(_ direction: Direction) {
        let phases: [Int64] = [1, 2, 4]
        var events: [CGEvent] = []

        let sign = Self.augmentedSign(direction)
        for phase in phases {
            guard let event = makeAugmentedSwipeEvent(
                      phase: phase, sign: sign, progress: phase == 4 ? 1 : Self.softStartProgress, endVelocity: velocity
                  ),
                  let augmented = augmentWithIOHIDPayload(event) else { return }
            events.append(augmented)
        }

        for event in events {
            postPair(dockEvent: event)
        }
    }

    private func makeAugmentedSwipeEvent(phase: Int64, sign: Double, progress: Double, endVelocity: Double) -> CGEvent? {
        guard let event = CGEvent(source: nil) else { return nil }

        event.setIntegerValueField(Self.eventTypeField, value: 30)
        event.setIntegerValueField(Self.gestureHIDType, value: 23)
        event.setIntegerValueField(Self.gesturePhase, value: phase)
        event.setDoubleValueField(Self.swipeProgress, value: sign * progress)
        event.setIntegerValueField(Self.swipeMotion, value: 1)
        event.setIntegerValueField(Self.gesturePhaseAlias, value: phase)
        event.setDoubleValueField(Self.gestureZoomDeltaY, value: 3)
        event.setDoubleValueField(Self.sourceProcessAlias, value: Double(mach_absolute_time()))
        event.setDoubleValueField(Self.swipePositionX, value: 0.1)

        if phase == 4 {
            event.setDoubleValueField(Self.swipeVelocityX, value: sign * endVelocity)
        }
        return event
    }

    private func postPair(dockEvent: CGEvent) {
        guard let companion = CGEvent(source: nil) else { return }
        companion.setIntegerValueField(Self.eventTypeField, value: 29)
        dockEvent.post(tap: .cgSessionEventTap)
        companion.post(tap: .cgSessionEventTap)
    }

    private func augmentWithIOHIDPayload(_ event: CGEvent) -> CGEvent? {
        guard let serialized = event.data else { return nil }
        var bytes = serialized as Data

        // CGEvent's flattened representation currently uses format version 2.
        guard bytes.count >= 4,
              bytes[0] == 0, bytes[1] == 0, bytes[2] == 0, bytes[3] == 2 else {
            return nil
        }

        let payload = makeIOHIDPayload(for: event)
        guard payload.count <= Int(UInt16.max) else { return nil }

        bytes.append(UInt8((payload.count >> 8) & 0xff))
        bytes.append(UInt8(payload.count & 0xff))
        bytes.append(UInt8((Self.rawIOHIDPayload >> 8) & 0xff))
        bytes.append(UInt8(Self.rawIOHIDPayload & 0xff))
        bytes.append(payload)

        return CGEvent(withDataAllocator: nil, data: bytes as CFData)
    }

    private func makeIOHIDPayload(for event: CGEvent) -> Data {
        let phase = event.getIntegerValueField(Self.gesturePhase)
        let motion = event.getIntegerValueField(Self.swipeMotion)
        let progress = event.getDoubleValueField(Self.swipeProgress)
        let positionX = event.getDoubleValueField(Self.swipePositionX)
        let positionY = event.getDoubleValueField(Self.swipePositionY)
        let velocityX = event.getDoubleValueField(Self.swipeVelocityX)
        let velocityY = event.getDoubleValueField(Self.swipeVelocityY)
        let swipeMask = event.getIntegerValueField(Self.swipeMask)
        let includeVelocity = velocityX != 0 || velocityY != 0 || phase == 4

        var payload = Data()

        // IOHIDSystemQueueElementHeader (28 bytes).
        let timestamp = event.timestamp == 0 ? mach_absolute_time() : event.timestamp
        Self.appendLittleEndian(timestamp, to: &payload)
        Self.appendLittleEndian(UInt64(0), to: &payload) // sender ID
        Self.appendLittleEndian(UInt32(0), to: &payload) // options
        Self.appendLittleEndian(UInt32(0), to: &payload) // attribute length
        Self.appendLittleEndian(UInt32(includeVelocity ? 2 : 1), to: &payload)

        // IOHIDFluidTouchGestureData (40 bytes).
        Self.appendLittleEndian(UInt32(40), to: &payload)
        Self.appendLittleEndian(UInt32(23), to: &payload)
        Self.appendLittleEndian(UInt32(truncatingIfNeeded: phase) << 24, to: &payload)
        Self.appendLittleEndian(UInt32(0), to: &payload) // depth + reserved bytes
        Self.appendLittleEndian(Self.fixed1616(positionX), to: &payload)
        Self.appendLittleEndian(Self.fixed1616(positionY), to: &payload)
        Self.appendLittleEndian(Int32(0), to: &payload)
        Self.appendLittleEndian(UInt32(truncatingIfNeeded: swipeMask), to: &payload)
        Self.appendLittleEndian(UInt16(truncatingIfNeeded: motion), to: &payload)
        Self.appendLittleEndian(UInt16(3), to: &payload) // Dock-primary flavor
        Self.appendLittleEndian(Self.fixed1616(progress), to: &payload)

        if includeVelocity {
            // IOHIDVelocityEventData (28 bytes).
            Self.appendLittleEndian(UInt32(28), to: &payload)
            Self.appendLittleEndian(UInt32(9), to: &payload)
            Self.appendLittleEndian(UInt32(0), to: &payload)
            payload.append(1) // child-event depth
            payload.append(contentsOf: [0, 0, 0])
            Self.appendLittleEndian(Self.fixed1616(velocityX), to: &payload)
            Self.appendLittleEndian(Self.fixed1616(velocityY), to: &payload)
            Self.appendLittleEndian(Int32(0), to: &payload)
        }

        return payload
    }

    private static func fixed1616(_ value: Double) -> Int32 {
        let fixed = Int32(clamping: Int64(value * 65_536))
        if fixed == 0, value != 0 { return value > 0 ? 1 : -1 }
        return fixed
    }

    private static func appendLittleEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }

    private static let eventTypeField = CGEventField(rawValue: 55)!
    private static let gestureHIDType = CGEventField(rawValue: 110)!
    private static let swipeMotion = CGEventField(rawValue: 123)!
    private static let swipeProgress = CGEventField(rawValue: 124)!
    private static let swipeVelocityX = CGEventField(rawValue: 129)!
    private static let swipeVelocityY = CGEventField(rawValue: 130)!
    private static let gesturePhase = CGEventField(rawValue: 132)!
    private static let swipeMask = CGEventField(rawValue: 115)!
    private static let swipePositionX = CGEventField(rawValue: 125)!
    private static let swipePositionY = CGEventField(rawValue: 126)!
    private static let gesturePhaseAlias = CGEventField(rawValue: 134)!
    private static let gestureZoomDeltaY = CGEventField(rawValue: 138)!
    private static let sourceProcessAlias = CGEventField(rawValue: 169)!
    private static let rawIOHIDPayload = 4205
}
