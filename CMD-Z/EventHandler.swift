//
//  EventHandler.swift
//  CMD-Z
//
//  Created by Toni Förster on 18.03.25.
//
//  SPDX-License-Identifier: MIT
//  Copyright (c) 2025 Toni Förster
//

import Carbon
import Cocoa
import OSLog

@MainActor
class EventHandler {
    static let shared = EventHandler()
    var eventTap: CFMachPort?

    private var accessibilityPollTimer: Timer?
    private var permissionMonitorTimer: Timer?
    private var eventTapRetryCount = 0
    private var runLoopSource: CFRunLoopSource?
    private var didShowRevocationAlert = false

    private let logger = Logger(subsystem: "de.fauler-apfel.CMD-Z", category: "EventHandler")

    func startEventTap() {
        guard eventTap == nil else {
            logger.info("Event tap is already running.")
            return
        }

        startPermissionMonitor()

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
            let granted = MainActor.assumeIsolated {
                AccessibilityChecker.shared.isAccessibilityEnabled
            }
            guard granted else { return }
            timer.invalidate()
            MainActor.assumeIsolated {
                self?.accessibilityPollTimer = nil
                self?.logger.info("Accessibility access granted. Proceeding with event tap setup.")
                self?.setupEventTap()
            }
        }
        accessibilityPollTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    /// Sets up the event tap once accessibility access is granted
    private func setupEventTap() {
        guard eventTap == nil else { return }

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
            eventTapRetryCount += 1
            if eventTapRetryCount <= 3 {
                let attempt = eventTapRetryCount
                logger.error("Failed to create event tap. Retrying (\(attempt)/3)...")
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
        self.runLoopSource = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    /// Monitors accessibility permission and reacts to mid-session revocation.
    private func startPermissionMonitor() {
        guard permissionMonitorTimer == nil else { return }

        let timer = Timer(timeInterval: 5.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let trusted = AccessibilityChecker.shared.isAccessibilityEnabled

                if !trusted, self.eventTap != nil {
                    self.stopEventTap()
                    if !self.didShowRevocationAlert {
                        self.didShowRevocationAlert = true
                        AccessibilityChecker.shared.showManualEnableAlert()
                    }
                } else if trusted, self.eventTap == nil {
                    self.didShowRevocationAlert = false
                    self.setupEventTap()
                }
            }
        }
        permissionMonitorTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func presentEventTapFailureAlert() {
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

    func stopEventTap() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
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
        if event.getIntegerValueField(.eventSourceUserData) == MacroHandler.syntheticTag {
            return Unmanaged.passUnretained(event)
        }

        if CapsLockHandler.isHyperKeyEvent(event) {
            let isHyperEnabled = AppDelegate.shared?.isHyperKeyEnabled ?? false
            return CapsLockHandler.shared.handle(type: type, event: event, isEnabled: isHyperEnabled)
        }

        let isHyperActive = CapsLockHandler.shared.isActive

        if isHyperActive, type == .keyDown {
            CapsLockHandler.shared.noteOtherKeyPressed()
        }

        if isHyperActive, event.getIntegerValueField(.keyboardEventKeycode) == Int64(kVK_ANSI_V) {
            if AppDelegate.shared?.isClipboardMacroEnabled ?? false {
                if type == .keyDown, event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                    MacroHandler.shared.triggerClipboardManager()
                }
                return nil
            }
        }

        if isHyperActive, event.getIntegerValueField(.keyboardEventKeycode) == Int64(kVK_Escape) {
            if type == .keyDown,
               event.getIntegerValueField(.keyboardEventAutorepeat) == 0,
               AppDelegate.shared?.isMenuSearchEnabled ?? false
            {
                MenuSearchController.shared.toggle()
            }
            return nil
        }

        let isEnabled = AppDelegate.shared?.isRemappingEnabled ?? true
        let result = KeyboardHandler.handleCGEvent(type: type, event: event, isRemappingEnabled: isEnabled)

        if isHyperActive, type == .keyDown || type == .keyUp {
            event.flags.formUnion(CapsLockHandler.hyperModifiers)
        }

        return result
    }
}
