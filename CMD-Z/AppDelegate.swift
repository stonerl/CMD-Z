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
import ServiceManagement

@main
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var isAutostartEnabled: Bool {
        let status = SMAppService.mainApp.status
        return status == .enabled || status == .requiresApproval
    }

    weak static var shared: AppDelegate?

    func applicationDidFinishLaunching(_: Notification) {
        // Assign shared instance
        AppDelegate.shared = self

        // Prevent the app from appearing in the Dock or having a visible main window
        NSApp.setActivationPolicy(.accessory)

        // Create and configure the menu bar item using MenuBarManager
        MenuBarManager.shared.createMenuBarItem()
        let menuConfig = MenuConfiguration(
            isRemappingEnabled: FeatureSettings.isRemappingEnabled,
            isHyperKeyEnabled: FeatureSettings.isHyperKeyEnabled,
            isClipboardMacroEnabled: FeatureSettings.isClipboardMacroEnabled,
            isMenuSearchEnabled: FeatureSettings.isMenuSearchEnabled,
            isAutostartEnabled: isAutostartEnabled
        )
        MenuBarManager.shared.setupMenu(
            actions: MenuActions(
                toggleRemapping: #selector(toggleRemapping),
                toggleHyperKey: #selector(toggleHyperKey),
                toggleClipboardMacro: #selector(toggleClipboardMacro),
                toggleMenuSearch: #selector(toggleMenuSearch),
                toggleAutostart: #selector(toggleAutostart),
                quit: #selector(quitApp)
            ),
            target: self,
            configuration: menuConfig
        )

        // Apply the Caps Lock -> F18 remap before starting the event tap
        CapsLockRemapper.setEnabled(FeatureSettings.isHyperKeyEnabled)

        // Start the key event tap using EventHandler
        EventHandler.shared.startEventTap()
    }

    @objc func toggleRemapping(_ sender: NSMenuItem) {
        FeatureSettings.isRemappingEnabled.toggle()
        sender.state = FeatureSettings.isRemappingEnabled ? .on : .off
        MenuBarManager.shared.updateAppearance(isEnabled: FeatureSettings.isRemappingEnabled)
    }

    @objc func toggleHyperKey(_ sender: NSMenuItem) {
        FeatureSettings.isHyperKeyEnabled.toggle()
        sender.state = FeatureSettings.isHyperKeyEnabled ? .on : .off
        CapsLockRemapper.setEnabled(FeatureSettings.isHyperKeyEnabled)
    }

    @objc func toggleClipboardMacro(_ sender: NSMenuItem) {
        FeatureSettings.isClipboardMacroEnabled.toggle()
        sender.state = FeatureSettings.isClipboardMacroEnabled ? .on : .off
    }

    @objc func toggleMenuSearch(_ sender: NSMenuItem) {
        FeatureSettings.isMenuSearchEnabled.toggle()
        sender.state = FeatureSettings.isMenuSearchEnabled ? .on : .off
    }

    @objc func toggleAutostart(_ sender: NSMenuItem) {
        let newValue = !isAutostartEnabled
        AutostartManager.shared.enableAutostart(newValue)
        sender.state = isAutostartEnabled ? .on : .off
    }

    @objc func quitApp() {
        EventHandler.shared.stopEventTap()
        CapsLockRemapper.clearBlocking()
        NSApplication.shared.terminate(self)
    }

    func applicationWillTerminate(_: Notification) {
        CapsLockRemapper.clearBlocking()
    }
}

extension AppDelegate: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(toggleClipboardMacro(_:)), #selector(toggleMenuSearch(_:)):
            FeatureSettings.isHyperKeyEnabled
        default:
            true
        }
    }
}
