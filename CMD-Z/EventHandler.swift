//
//  EventHandler.swift
//  CMD-Z
//
//  Created by Toni Förster on 18.03.25.
//
//  SPDX-License-Identifier: MIT
//  Copyright (c) 2025 Toni Förster
//

import Cocoa
import OSLog

class EventHandler {
    static let shared = EventHandler()
    var eventTap: CFMachPort?

    private var accessibilityPollTimer: Timer?

    private let logger = Logger(subsystem: "de.fauler-apfel.CMD-Z", category: "EventHandler")

    func startEventTap() {
        guard eventTap == nil else {
            logger.info("Event tap is already running.")
            return
        }

        if AccessibilityChecker.shared.isAccessibilityEnabled {
            setupEventTap()
            return
        }

        if AccessibilityChecker.shared.isAppInAccessibilityList {
            // App is in the list but not enabled—prompt user to enable manually
            AccessibilityChecker.shared.showManualEnableAlert()
            waitForAccessibilityAndSetup()
            return
        }

        // Step 1: Show our dialog first
        AccessibilityChecker.shared.showAccessibilityAlert {
            self.logger.info("User clicked Continue. Triggering system dialog...")

            // Step 2: Attempt event tap setup to trigger macOS system prompt
            self.setupEventTap()

            // Step 3: Start polling for accessibility access
            self.waitForAccessibilityAndSetup()
        }
    }

    /// Polls for accessibility access and sets up the event tap once granted
    private func waitForAccessibilityAndSetup() {
        guard accessibilityPollTimer == nil else { return }

        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] timer in
            guard AccessibilityChecker.shared.isAccessibilityEnabled else { return }
            timer.invalidate()
            self?.accessibilityPollTimer = nil
            DispatchQueue.main.async {
                self?.logger.info("Accessibility access granted. Proceeding with event tap setup.")
                self?.setupEventTap()
            }
        }
        accessibilityPollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    /// Sets up the event tap once accessibility access is granted
    private func setupEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: EventHandler.eventTapCallback,
            userInfo: nil
        )

        guard let eventTap else {
            logger.error("Failed to create event tap")
            return
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func stopEventTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
    }

    static let eventTapCallback: CGEventTapCallBack = { _, type, event, _ in
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let eventTap = EventHandler.shared.eventTap {
                    CGEvent.tapEnable(tap: eventTap, enable: true)
                }
            }
            return Unmanaged.passUnretained(event)
        }
        return EventHandler.shared.handleCGEvent(type: type, event: event)
    }

    func handleCGEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // Only process if Command key is active and Y or Z
        guard flags.contains(.maskCommand), keyCode == Int64(KeyCode.ansiZ) || keyCode == Int64(KeyCode.ansiY) else {
            return Unmanaged.passUnretained(event)
        }

        return KeyboardHandler.handleCGEvent(type: type, event: event)
    }
}
