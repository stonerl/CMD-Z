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

        // Create and configure the menu bar item using MenuBarManager
        MenuBarManager.shared.createMenuBarItem()
        MenuBarManager.shared.setupMenu(
            toggleRemappingAction: #selector(toggleRemapping),
            toggleAutostartAction: #selector(toggleAutostart),
            quitAction: #selector(quitApp),
            target: self,
            isRemappingEnabled: isRemappingEnabled,
            isAutostartEnabled: isAutostartEnabled
        )

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
        KeyboardHandler.handleCGEvent(type: type, event: event)
    }

    @objc func quitApp() {
        EventHandler.shared.stopEventTap()
        NSApplication.shared.terminate(self)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }
}
