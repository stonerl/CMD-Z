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
    let isClipboardMacroEnabled: Bool
    let isMenuSearchEnabled: Bool
    let isAutostartEnabled: Bool
}

struct MenuActions {
    let toggleRemapping: Selector
    let toggleHyperKey: Selector
    let toggleClipboardMacro: Selector
    let toggleMenuSearch: Selector
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

        menu.addItem(toggleItem(
            title: NSLocalizedString("Remapping", comment: "Menu item toggles remapping"),
            action: actions.toggleRemapping,
            keyEquivalent: "e",
            target: target,
            isOn: configuration.isRemappingEnabled
        ))
        menu.addItem(toggleItem(
            title: NSLocalizedString("Hyper Key", comment: "Menu item toggles Hyper Key"),
            action: actions.toggleHyperKey,
            keyEquivalent: "h",
            target: target,
            isOn: configuration.isHyperKeyEnabled
        ))
        menu.addItem(toggleItem(
            title: NSLocalizedString("Clipboard", comment: "Menu item toggles clipboard macro"),
            action: actions.toggleClipboardMacro,
            keyEquivalent: "c",
            target: target,
            isOn: configuration.isClipboardMacroEnabled
        ))
        menu.addItem(toggleItem(
            title: NSLocalizedString("Menu Search", comment: "Menu item toggles menu search"),
            action: actions.toggleMenuSearch,
            keyEquivalent: "s",
            target: target,
            isOn: configuration.isMenuSearchEnabled
        ))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(toggleItem(
            title: NSLocalizedString("Open at Login", comment: "Menu item toggles launch at login"),
            action: actions.toggleAutostart,
            keyEquivalent: "l",
            target: target,
            isOn: configuration.isAutostartEnabled
        ))

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

    private func toggleItem(title: String,
                            action: Selector,
                            keyEquivalent: String,
                            target: AnyObject,
                            isOn: Bool) -> NSMenuItem
    {
        let item = NSMenuItem(
            title: title,
            action: action,
            keyEquivalent: keyEquivalent
        )
        item.target = target
        item.state = isOn ? .on : .off
        return item
    }
}
