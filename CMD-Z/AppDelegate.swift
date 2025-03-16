//
//  AppDelegate.swift
//  CMD-Z
//
//  Created by Toni Förster on 16.03.25.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var eventTap: CFMachPort?

    static var shared: AppDelegate?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Assign shared instance
        AppDelegate.shared = self

        // Prevent the app from appearing in the Dock or having a visible main window
        NSApp.setActivationPolicy(.accessory)

        // Manually activate the app to prevent immediate termination
        NSApp.activate(ignoringOtherApps: true)

        // Create a menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "Z↔Y"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem?.menu = menu

        // Start the key event tap (if used)
        startEventTap()
    }

    func startEventTap() {
        guard eventTap == nil else {
            print("Event tap is already running.")
            return
        }

        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: AppDelegate.eventTapCallback,
            userInfo: nil
        )

        guard let eventTap = eventTap else {
            print("Failed to create event tap")
            return
        }

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    static let eventTapCallback: CGEventTapCallBack = { _, type, event, _ in
        AppDelegate.shared?.handleCGEvent(type: type, event: event) ?? Unmanaged.passUnretained(event)
    }

    func handleCGEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        if flags.contains(.maskCommand) {
            if keyCode == 6 { // 'Z' key
                event.setIntegerValueField(.keyboardEventKeycode, value: 16) // Change to 'Y'
            } else if keyCode == 16 { // 'Y' key
                event.setIntegerValueField(.keyboardEventKeycode, value: 6) // Change to 'Z'
            }
        }

        return Unmanaged.passUnretained(event)
    }

    @objc func quitApp() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        NSApplication.shared.terminate(self)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
