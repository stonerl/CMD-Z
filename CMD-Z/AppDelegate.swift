//
//  AppDelegate.swift
//  CMD-Z
//
//  Created by Toni Förster on 16.03.25.
//

import Cocoa
import ServiceManagement

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var eventTap: CFMachPort?
    var isRemappingEnabled = true // Track remapping state
    var isAutostartEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "isAutostartEnabled") }
        set { UserDefaults.standard.setValue(newValue, forKey: "isAutostartEnabled") }
    }

    static var shared: AppDelegate?

    func applicationDidFinishLaunching(_: Notification) {
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

        let toggleItem = NSMenuItem(title: "Enabled", action: #selector(toggleRemapping), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.state = isRemappingEnabled ? .on : .off
        menu.addItem(toggleItem)

        let autostartItem = NSMenuItem(title: "Start at Login", action: #selector(toggleAutostart), keyEquivalent: "")
        autostartItem.target = self
        autostartItem.state = isAutostartEnabled ? .on : .off
        menu.addItem(autostartItem)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit CMD-Z", action: #selector(quitApp), keyEquivalent: ""))
        statusItem?.menu = menu

        // Start the key event tap (if used)
        startEventTap()

        // Ensure autostart is enabled if previously set
        if isAutostartEnabled {
            enableAutostart(true)
        }
    }

    @objc func toggleRemapping(_ sender: NSMenuItem) {
        isRemappingEnabled.toggle()
        sender.state = isRemappingEnabled ? .on : .off

        if let button = statusItem?.button {
            button.title = isRemappingEnabled ? "Z↔Y" : "Z↔Y"
            button.attributedTitle = NSAttributedString(
                string: button.title,
                attributes: [.foregroundColor: isRemappingEnabled ?
                    NSColor.labelColor :
                    NSColor.labelColor.withAlphaComponent(0.5)]
            )
        }
    }

    @objc func toggleAutostart(_ sender: NSMenuItem) {
        isAutostartEnabled.toggle()
        sender.state = isAutostartEnabled ? .on : .off
        enableAutostart(isAutostartEnabled)
    }

    func enableAutostart(_ enable: Bool) {
        let appService = SMAppService.mainApp

        do {
            if enable {
                try appService.register()
                print("Start at Login enabled")
            } else {
                try appService.unregister()
                print("Start at Login disabled")
            }
        } catch {
            print("Failed to update Start at Login setting: \(error)")
        }
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

        guard let eventTap else {
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

    func handleCGEvent(type _: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard isRemappingEnabled else {
            return Unmanaged.passUnretained(event)
        }

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
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        NSApplication.shared.terminate(self)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }
}
