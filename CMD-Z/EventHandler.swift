//
//  EventHandler.swift
//  CMD-Z
//
//  Created by Toni Förster on 18.03.25.
//

import Cocoa
import OSLog

class EventHandler {
    static let shared = EventHandler()
    var eventTap: CFMachPort?

    private let logger = Logger(subsystem: "de.fauler-apfel.CMD-Z", category: "EventHandler")

    func startEventTap() {
        guard eventTap == nil else {
            logger.info("Event tap is already running.")
            return
        }

        // If accessibility access is already granted, proceed immediately
        if AccessibilityChecker.shared.isAccessibilityEnabled {
            setupEventTap()
            return
        }

        // Show alert once and start polling for access
        DispatchQueue.main.async {
            AccessibilityChecker.shared.showAccessibilityAlert {
                // Start checking periodically if access is granted
                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                    if AccessibilityChecker.shared.isAccessibilityEnabled {
                        timer.invalidate() // Stop checking
                        DispatchQueue.main.async {
                            self.logger.info("Accessibility access granted. Proceeding with event tap setup.")
                            self.setupEventTap()
                        }
                    }
                }
            }
        }
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
            if let eventTap = EventHandler.shared.eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }
        return EventHandler.shared.handleCGEvent(type: type, event: event)
    }

    func handleCGEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        // Only process if Command key is active and Y or Z
        guard flags.contains(.maskCommand), keyCode == 6 || keyCode == 16 else {
            return Unmanaged.passUnretained(event)
        }

        return KeyboardHandler.handleCGEvent(type: type, event: event)
    }
}
