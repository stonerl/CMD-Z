//
//  AppDelegate.swift
//  CMD-Z
//
//  Created by Toni Förster on 16.03.25.
//

import Cocoa
import OSLog
import ServiceManagement

private let logger = Logger(subsystem: "de.fauler-apfel.CMD-Z", category: "AppDelegate")

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var isRemappingEnabled = true
    var isAutostartEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "isAutostartEnabled") }
        set { UserDefaults.standard.setValue(newValue, forKey: "isAutostartEnabled") }
    }

    private func updateStatusItemAppearance() {
        guard let button = statusItem?.button else { return }
        button.alphaValue = isRemappingEnabled ? 1.0 : 0.5
    }

    static var shared: AppDelegate?

    func applicationDidFinishLaunching(_: Notification) {
        // Assign shared instance
        AppDelegate.shared = self

        // Prevent the app from appearing in the Dock or having a visible main window
        NSApp.setActivationPolicy(.accessory)

        // Create a menu bar item using the asset from the asset catalog
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            if let image = NSImage(named: "MenuBar") {
                // Set the image size to fit the menubar; adjust dimensions as needed
                image.size = NSSize(width: 21, height: 21)
                button.image = image
            }
        }

        let menu = NSMenu()

        let toggleItem = NSMenuItem(
            title: NSLocalizedString("Enabled", comment: "Menu item for enabling or disabling remapping"),
            action: #selector(toggleRemapping),
            keyEquivalent: ""
        )
        toggleItem.target = self
        toggleItem.state = isRemappingEnabled ? .on : .off
        menu.addItem(toggleItem)

        let autostartItem = NSMenuItem(
            title: NSLocalizedString("Start at Login", comment: "Menu item for toggling autostart"),
            action: #selector(toggleAutostart),
            keyEquivalent: ""
        )
        autostartItem.target = self
        autostartItem.state = isAutostartEnabled ? .on : .off
        menu.addItem(autostartItem)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(
            NSMenuItem(
                title: NSLocalizedString("Quit CMD-Z", comment: "Menu item for quitting the application"),
                action: #selector(quitApp),
                keyEquivalent: ""
            )
        )
        statusItem?.menu = menu

        // Start the key event tap using EventHandler
        EventHandler.shared.startEventTap()

        // Ensure autostart is enabled if previously set
        if isAutostartEnabled {
            AutostartManager.shared.enableAutostart(true)
        }
    }

    @objc func toggleRemapping(_ sender: NSMenuItem) {
        isRemappingEnabled.toggle()
        sender.state = isRemappingEnabled ? .on : .off
        updateStatusItemAppearance()
    }

    @objc func toggleAutostart(_ sender: NSMenuItem) {
        isAutostartEnabled.toggle()
        sender.state = isAutostartEnabled ? .on : .off
        AutostartManager.shared.enableAutostart(isAutostartEnabled)
    }

    func handleCGEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        return KeyboardHandler.handleCGEvent(type: type, event: event)
    }

    @objc func quitApp() {
        EventHandler.shared.stopEventTap()
        NSApplication.shared.terminate(self)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }
}
