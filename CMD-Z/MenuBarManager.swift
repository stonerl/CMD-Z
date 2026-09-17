//
//  MenuBarManager.swift
//  CMD-Z
//
//  Created by Toni Förster on 18.03.25.
//
//  SPDX-License-Identifier: MIT
//  Copyright (c) 2025 Toni Förster
//

import Cocoa

struct MenuConfiguration {
    let isRemappingEnabled: Bool
    let isHyperKeyEnabled: Bool
    let isAutostartEnabled: Bool
}

struct MenuActions {
    let toggleRemapping: Selector
    let toggleHyperKey: Selector
    let toggleAutostart: Selector
    let quit: Selector
}

@MainActor
class MenuBarManager {
    static let shared = MenuBarManager()
    var statusItem: NSStatusItem?

    /// Creates the menu bar item using the asset catalog image.
    func createMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }

        if let image = NSImage(named: "MenuBar")?.copy() as? NSImage {
            // Adjust the image size to fit the menu bar
            image.size = NSSize(width: 24, height: 24)
            image.isTemplate = true // Ensures the image adapts to light/dark mode
            button.image = image
        }
    }

    /// Updates the appearance (e.g. alpha) of the status item.
    func updateAppearance(isEnabled: Bool) {
        guard let button = statusItem?.button else { return }
        button.alphaValue = isEnabled ? 1.0 : 0.5
    }

    /// Sets up the menu for the status item.
    /// - Parameters:
    ///   - actions: The selectors for the menu item actions.
    ///   - target: The target object (e.g. AppDelegate) for the menu actions.
    ///   - configuration: A MenuConfiguration object containing the current remapping and autostart states.
    func setupMenu(actions: MenuActions,
                   target: AnyObject,
                   configuration: MenuConfiguration)
    {
        let menu = NSMenu()

        let toggleItem = NSMenuItem(
            title: NSLocalizedString("Enabled", comment: "Menu item for enabling or disabling remapping"),
            action: actions.toggleRemapping,
            keyEquivalent: "e"
        )
        toggleItem.target = target
        toggleItem.state = configuration.isRemappingEnabled ? .on : .off
        menu.addItem(toggleItem)

        let hyperKeyItem = NSMenuItem(
            title: NSLocalizedString("Hyper Key", comment: "Menu item for toggling the Caps Lock hyper key"),
            action: actions.toggleHyperKey,
            keyEquivalent: ""
        )
        hyperKeyItem.target = target
        hyperKeyItem.state = configuration.isHyperKeyEnabled ? .on : .off
        menu.addItem(hyperKeyItem)

        let autostartItem = NSMenuItem(
            title: NSLocalizedString("Open at Login", comment: "Menu item for toggling autostart"),
            action: actions.toggleAutostart,
            keyEquivalent: "l"
        )
        autostartItem.target = target
        autostartItem.state = configuration.isAutostartEnabled ? .on : .off
        menu.addItem(autostartItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: NSLocalizedString("Quit CMD-Z", comment: "Menu item for quitting the application"),
            action: actions.quit,
            keyEquivalent: "q"
        )
        quitItem.target = target
        menu.addItem(quitItem)

        statusItem?.menu = menu
        updateAppearance(isEnabled: configuration.isRemappingEnabled)
    }
}
