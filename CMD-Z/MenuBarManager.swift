//
//  MenuBarManager.swift
//  CMD-Z
//
//  Created by Toni Förster on 18.03.25.
//

import Cocoa

struct MenuConfiguration {
    let isRemappingEnabled: Bool
    let isAutostartEnabled: Bool
}

class MenuBarManager: NSObject, NSMenuDelegate {
    static let shared = MenuBarManager()
    var statusItem: NSStatusItem?

    // Store the last configuration parameters for dynamic menu updates
    var lastToggleRemappingAction: Selector?
    var lastToggleAutostartAction: Selector?
    var lastQuitAction: Selector?
    var lastTarget: AnyObject?
    var lastConfiguration: MenuConfiguration?

    /// Creates the menu bar item using the asset catalog image.
    func createMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }

        if let image = NSImage(named: "MenuBar") {
            // Adjust the image size to fit the menu bar
            image.size = NSSize(width: 24, height: 24)
            image.isTemplate = true // Ensures the image adapts to light/dark mode
            button.image = image
        }
        updateAppearance(isEnabled: true)
    }

    /// Updates the appearance (e.g. alpha) of the status item.
    func updateAppearance(isEnabled: Bool) {
        guard let button = statusItem?.button else { return }
        button.alphaValue = isEnabled ? 1.0 : 0.5
    }

    /// Sets up the menu for the status item.
    /// - Parameters:
    ///   - toggleRemappingAction: The selector for toggling remapping.
    ///   - toggleAutostartAction: The selector for toggling autostart.
    ///   - quitAction: The selector for quitting the app.
    ///   - target: The target object (e.g. AppDelegate) for the menu actions.
    ///   - configuration: A MenuConfiguration object containing the current remapping and autostart states.
    func setupMenu(toggleRemappingAction: Selector,
                   toggleAutostartAction: Selector,
                   quitAction: Selector,
                   target: AnyObject,
                   configuration: MenuConfiguration)
    {
        let menu = NSMenu()

        // Save configuration for dynamic updates
        lastToggleRemappingAction = toggleRemappingAction
        lastToggleAutostartAction = toggleAutostartAction
        lastQuitAction = quitAction
        lastTarget = target
        lastConfiguration = configuration

        // Set the menu delegate to self for dynamic updates
        menu.delegate = self

        if !AccessibilityChecker.shared.isAccessibilityEnabled {
            let accessibilityItem = NSMenuItem(
                title: NSLocalizedString("Enable Accessibility", comment: "Menu item to open Accessibility settings"),
                action: #selector(AccessibilityChecker.openAccessibilitySettings),
                keyEquivalent: ""
            )
            accessibilityItem.target = AccessibilityChecker.shared
            menu.addItem(accessibilityItem)
            menu.addItem(NSMenuItem.separator())
        }

        let toggleItem = NSMenuItem(
            title: NSLocalizedString("Enabled", comment: "Menu item for enabling or disabling remapping"),
            action: toggleRemappingAction,
            keyEquivalent: ""
        )
        toggleItem.target = target
        toggleItem.state = configuration.isRemappingEnabled ? .on : .off
        menu.addItem(toggleItem)

        let autostartItem = NSMenuItem(
            title: NSLocalizedString("Start at Login", comment: "Menu item for toggling autostart"),
            action: toggleAutostartAction,
            keyEquivalent: ""
        )
        autostartItem.target = target
        autostartItem.state = configuration.isAutostartEnabled ? .on : .off
        menu.addItem(autostartItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: NSLocalizedString("Quit CMD-Z", comment: "Menu item for quitting the application"),
            action: quitAction,
            keyEquivalent: ""
        )
        quitItem.target = target
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }
}

extension MenuBarManager {
    func menuNeedsUpdate(_ menu: NSMenu) {
        // Remove all existing items
        menu.removeAllItems()

        // Rebuild the menu using the last stored configuration
        guard let target = lastTarget,
              let toggleRemappingAction = lastToggleRemappingAction,
              let toggleAutostartAction = lastToggleAutostartAction,
              let quitAction = lastQuitAction,
              let configuration = lastConfiguration
        else {
            return
        }

        if !AccessibilityChecker.shared.isAccessibilityEnabled {
            let accessibilityItem = NSMenuItem(
                title: NSLocalizedString("Enable Accessibility", comment: "Menu item to open Accessibility settings"),
                action: #selector(AccessibilityChecker.openAccessibilitySettings),
                keyEquivalent: ""
            )
            accessibilityItem.target = AccessibilityChecker.shared
            menu.addItem(accessibilityItem)
            menu.addItem(NSMenuItem.separator())
        }

        let toggleItem = NSMenuItem(
            title: NSLocalizedString("Enabled", comment: "Menu item for enabling or disabling remapping"),
            action: toggleRemappingAction,
            keyEquivalent: ""
        )
        toggleItem.target = target
        toggleItem.state = configuration.isRemappingEnabled ? .on : .off
        menu.addItem(toggleItem)

        let autostartItem = NSMenuItem(
            title: NSLocalizedString("Start at Login", comment: "Menu item for toggling autostart"),
            action: toggleAutostartAction,
            keyEquivalent: ""
        )
        autostartItem.target = target
        autostartItem.state = configuration.isAutostartEnabled ? .on : .off
        menu.addItem(autostartItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: NSLocalizedString("Quit CMD-Z", comment: "Menu item for quitting the application"),
            action: quitAction,
            keyEquivalent: ""
        )
        quitItem.target = target
        menu.addItem(quitItem)
    }
}
