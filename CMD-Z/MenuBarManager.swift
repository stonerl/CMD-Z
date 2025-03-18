//
//  MenuBarManager.swift
//  CMD-Z
//
//  Created by Toni Förster on 18.03.25.
//

import Cocoa

class MenuBarManager {
    static let shared = MenuBarManager()
    var statusItem: NSStatusItem?

    /// Creates the menu bar item using the asset catalog image.
    func createMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        if let image = NSImage(named: "MenuBar") {
            // Adjust the image size to fit the menu bar
            image.size = NSSize(width: 21, height: 21)
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
    ///   - isRemappingEnabled: The current remapping state.
    ///   - isAutostartEnabled: The current autostart state.
    func setupMenu(toggleRemappingAction: Selector,
                   toggleAutostartAction: Selector,
                   quitAction: Selector,
                   target: AnyObject,
                   isRemappingEnabled: Bool,
                   isAutostartEnabled: Bool)
    {
        let menu = NSMenu()

        let toggleItem = NSMenuItem(
            title: NSLocalizedString("Enabled", comment: "Menu item for enabling or disabling remapping"),
            action: toggleRemappingAction,
            keyEquivalent: ""
        )
        toggleItem.target = target
        toggleItem.state = isRemappingEnabled ? .on : .off
        menu.addItem(toggleItem)

        let autostartItem = NSMenuItem(
            title: NSLocalizedString("Start at Login", comment: "Menu item for toggling autostart"),
            action: toggleAutostartAction,
            keyEquivalent: ""
        )
        autostartItem.target = target
        autostartItem.state = isAutostartEnabled ? .on : .off
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
