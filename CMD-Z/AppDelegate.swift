//
//  AppDelegate.swift
//  CMD-Z
//
//  Created by Toni Förster on 16.03.25.
//
//  SPDX-License-Identifier: MIT
//  Copyright (c) 2025 Toni Förster
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

    static var shared: AppDelegate?

    func applicationDidFinishLaunching(_: Notification) {
        // Assign shared instance
        AppDelegate.shared = self

        // Prevent the app from appearing in the Dock or having a visible main window
        NSApp.setActivationPolicy(.accessory)

        // Create and configure the menu bar item using MenuBarManager
        MenuBarManager.shared.createMenuBarItem()
        let menuConfig = MenuConfiguration(
            isRemappingEnabled: isRemappingEnabled,
            isAutostartEnabled: isAutostartEnabled
        )
        MenuBarManager.shared.setupMenu(
            toggleRemappingAction: #selector(toggleRemapping),
            toggleAutostartAction: #selector(toggleAutostart),
            quitAction: #selector(quitApp),
            target: self,
            configuration: menuConfig
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
        MenuBarManager.shared.updateAppearance(isEnabled: isRemappingEnabled)
    }

    @objc func toggleAutostart(_ sender: NSMenuItem) {
        isAutostartEnabled.toggle()
        sender.state = isAutostartEnabled ? .on : .off
        AutostartManager.shared.enableAutostart(isAutostartEnabled)
    }

    @objc func quitApp() {
        EventHandler.shared.stopEventTap()
        NSApplication.shared.terminate(self)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }
}
