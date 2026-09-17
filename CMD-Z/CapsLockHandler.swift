//
//  CapsLockHandler.swift
//  CMD-Z
//
//  Created by Toni Förster on 17.09.26.
//
//  SPDX-License-Identifier: MIT
//  Copyright (c) 2026 Toni Förster
//

import Carbon
import Cocoa
import IOKit.hid

@MainActor
final class CapsLockHandler {
    static let shared = CapsLockHandler()

    static let hyperModifiers: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]
    static let tapThreshold: TimeInterval = 0.25

    private let hyperKeyCode = Int64(kVK_F18)

    private var isHyperActive = false
    private var hyperKeyDownTime: TimeInterval = 0
    private var pressedOtherKeyWhileHolding = false
    private var hidConnection: io_connect_t = IO_OBJECT_NULL

    var isActive: Bool {
        isHyperActive
    }

    /// Returns true if the event originates from the remapped Caps Lock key (F18).
    static func isHyperKeyEvent(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.keyboardEventKeycode) == Int64(kVK_F18)
    }

    /// Handles the hyper key: tap toggles caps lock, hold acts as a hyper modifier.
    func handle(type: CGEventType, event: CGEvent, isEnabled: Bool) -> Unmanaged<CGEvent>? {
        guard isEnabled else {
            resetState()
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .keyDown:
            guard !isHyperActive else {
                return nil
            }
            isHyperActive = true
            hyperKeyDownTime = ProcessInfo.processInfo.systemUptime
            pressedOtherKeyWhileHolding = false
            return nil

        case .keyUp:
            guard isHyperActive else {
                return Unmanaged.passUnretained(event)
            }
            let duration = ProcessInfo.processInfo.systemUptime - hyperKeyDownTime
            let wasTap = duration < Self.tapThreshold && !pressedOtherKeyWhileHolding
            resetState()
            if wasTap {
                setCapsLockState(!capsLockState())
            }
            return nil

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    /// Marks that another key was pressed while the hyper key is held.
    func noteOtherKeyPressed() {
        pressedOtherKeyWhileHolding = true
    }

    private func resetState() {
        isHyperActive = false
        pressedOtherKeyWhileHolding = false
    }

    private func makeHidConnection() -> io_connect_t {
        if hidConnection != IO_OBJECT_NULL {
            return hidConnection
        }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"))
        guard service != IO_OBJECT_NULL else {
            return IO_OBJECT_NULL
        }
        var connection: io_connect_t = IO_OBJECT_NULL
        IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connection)
        IOObjectRelease(service)
        hidConnection = connection
        return connection
    }

    private func capsLockState() -> Bool {
        let connection = makeHidConnection()
        guard connection != IO_OBJECT_NULL else {
            return false
        }
        var isOn = false
        IOHIDGetModifierLockState(connection, Int32(kIOHIDCapsLockState), &isOn)
        return isOn
    }

    private func setCapsLockState(_ enabled: Bool) {
        let connection = makeHidConnection()
        guard connection != IO_OBJECT_NULL else {
            return
        }
        IOHIDSetModifierLockState(connection, Int32(kIOHIDCapsLockState), enabled)
    }
}
