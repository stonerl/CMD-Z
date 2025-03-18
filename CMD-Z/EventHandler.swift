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

        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
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
        KeyboardHandler.handleCGEvent(type: type, event: event)
    }
}
