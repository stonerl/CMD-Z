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
    var isRemappingEnabled = true
    var isHyperKeyEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: "isHyperKeyEnabled") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "isHyperKeyEnabled")
        }
        set { UserDefaults.standard.set(newValue, forKey: "isHyperKeyEnabled") }
    }

    var isClipboardMacroEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: "isClipboardMacroEnabled") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "isClipboardMacroEnabled")
        }
        set { UserDefaults.standard.set(newValue, forKey: "isClipboardMacroEnabled") }
    }

    var isMenuSearchEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: "isMenuSearchEnabled") == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: "isMenuSearchEnabled")
        }
        set { UserDefaults.standard.set(newValue, forKey: "isMenuSearchEnabled") }
    }

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
            isRemappingEnabled: isRemappingEnabled,
            isHyperKeyEnabled: isHyperKeyEnabled,
            isClipboardMacroEnabled: isClipboardMacroEnabled,
            isMenuSearchEnabled: isMenuSearchEnabled,
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
        CapsLockRemapper.setEnabled(isHyperKeyEnabled)

        // Start the key event tap using EventHandler
        EventHandler.shared.startEventTap()
    }

    @objc func toggleRemapping(_ sender: NSMenuItem) {
        isRemappingEnabled.toggle()
        sender.state = isRemappingEnabled ? .on : .off
        MenuBarManager.shared.updateAppearance(isEnabled: isRemappingEnabled)
    }

    @objc func toggleHyperKey(_ sender: NSMenuItem) {
        isHyperKeyEnabled.toggle()
        sender.state = isHyperKeyEnabled ? .on : .off
        CapsLockRemapper.setEnabled(isHyperKeyEnabled)
    }

    @objc func toggleClipboardMacro(_ sender: NSMenuItem) {
        isClipboardMacroEnabled.toggle()
        sender.state = isClipboardMacroEnabled ? .on : .off
    }

    @objc func toggleMenuSearch(_ sender: NSMenuItem) {
        isMenuSearchEnabled.toggle()
        sender.state = isMenuSearchEnabled ? .on : .off
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
