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
    private var eventTapRetryCount = 0

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
            eventTapRetryCount += 1
            if eventTapRetryCount <= 3 {
                logger.error("Failed to create event tap. Retrying (\(self.eventTapRetryCount)/3)...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.setupEventTap()
                }
            } else {
                logger.error("Failed to create event tap after retries")
                presentEventTapFailureAlert()
            }
            return
        }

        eventTapRetryCount = 0
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func presentEventTapFailureAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Error", comment: "Alert title for errors")
            alert.informativeText = NSLocalizedString(
                "CMD-Z could not start. Please restart the app.",
                comment: "Alert message when the event tap fails to start"
            )
            alert.alertStyle = .warning
            alert.addButton(withTitle: NSLocalizedString("Quit", comment: "Quit button title"))
            alert.runModal()
            AppDelegate.shared?.quitApp()
        }
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
        let isEnabled = AppDelegate.shared?.isRemappingEnabled ?? true
        return KeyboardHandler.handleCGEvent(type: type, event: event, isRemappingEnabled: isEnabled)
    }
}
