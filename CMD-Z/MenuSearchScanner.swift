//
//  MenuSearchScanner.swift
//  CMD-Z
//
//  Created by Toni Förster on 17.09.26.
//
//  SPDX-License-Identifier: MIT
//  Copyright (c) 2026 Toni Förster
//

import ApplicationServices
import Cocoa

/// The key equivalent of a menu item, kept raw enough to match against a real key event.
struct MenuShortcut: Sendable, Equatable {
    let display: String
    let keyChar: String
    let modifiers: Int

    /// Carbon `MenuCommandModifiers` bits: 1=⇧, 2=⌥, 4=⌃, 8=no-⌘.
    func matches(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags
        let wantsCommand = (modifiers & 8) == 0
        guard flags.contains(.command) == wantsCommand,
              flags.contains(.shift) == ((modifiers & 1) != 0),
              flags.contains(.option) == ((modifiers & 2) != 0),
              flags.contains(.control) == ((modifiers & 4) != 0)
        else {
            return false
        }
        guard let eventChar = event.charactersIgnoringModifiers?.lowercased(), !eventChar.isEmpty else {
            return false
        }
        return eventChar == keyChar.lowercased()
    }
}

/// The kind of mark a menu uses, inferred from its items' mark characters.
enum MenuMarkKind: Sendable, Equatable {
    case none
    case check
    case radio
}

/// A single searchable menu item, represented as Sendable value types so it can cross actors.
struct MenuEntry: Sendable, Equatable {
    let title: String
    let path: [String]
    let shortcut: MenuShortcut?
    let mark: String?
    let markKind: MenuMarkKind
    let enabled: Bool

    var displayPath: String {
        path.joined(separator: " > ")
    }

    var pathKey: String {
        path.joined(separator: "\u{1}")
    }
}

/// Reads and triggers the frontmost application's menu bar via the Accessibility API.
/// All methods are synchronous and blocking (AX XPC) — call them off the main actor.
enum MenuSearchScanner {
    private static let walkBudget: TimeInterval = 1.0
    private static let sweepTimeout: Float = 0.2

    /// Recursively walks the menu bar of `pid` and returns a flat list of leaf menu items.
    static func entries(for pid: pid_t) -> [MenuEntry] {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.5)

        guard let menuBar = element(app, kAXMenuBarAttribute) else {
            return []
        }

        var result: [MenuEntry] = []
        let deadline = Date().addingTimeInterval(walkBudget)

        // Skip the first menu bar item (the global Apple menu).
        for item in children(of: menuBar).dropFirst() {
            guard let title = string(item, kAXTitleAttribute), !title.isEmpty else {
                continue
            }
            walk(item, path: [title], deadline: deadline, into: &result)
        }
        return result
    }

    /// Triggers the menu item at `path` by resolving its leaf element and pressing it directly.
    static func trigger(path: [String], pid: pid_t) -> Bool {
        Thread.sleep(forTimeInterval: 0.15)

        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.5)

        guard let menuBar = element(app, kAXMenuBarAttribute) else {
            return false
        }

        var items = children(of: menuBar)
        var leaf: AXUIElement?
        for (index, title) in path.enumerated() {
            guard let match = items.first(where: { string($0, kAXTitleAttribute) == title }) else {
                return false
            }
            leaf = match
            if index < path.count - 1 {
                items = flattenedChildren(of: match)
            }
        }

        guard let leaf else {
            return false
        }
        return AXUIElementPerformAction(leaf, kAXPressAction as CFString) == .success
    }

    // MARK: - Walk

    private static func walk(_ element: AXUIElement,
                             path: [String],
                             deadline: Date,
                             into entries: inout [MenuEntry])
    {
        guard Date() < deadline else { return }

        let children = flattenedChildren(of: element)
        let kind = markKind(in: children)

        for child in children {
            guard Date() < deadline else { return }
            AXUIElementSetMessagingTimeout(child, sweepTimeout)

            let title = string(child, kAXTitleAttribute) ?? ""
            let nested = flattenedChildren(of: child)

            if nested.isEmpty {
                if !title.isEmpty {
                    entries.append(MenuEntry(
                        title: title,
                        path: path + [title],
                        shortcut: shortcut(for: child),
                        mark: mark(for: child),
                        markKind: kind,
                        enabled: bool(child, kAXEnabledAttribute) ?? true
                    ))
                }
            } else {
                walk(child, path: path + [title], deadline: deadline, into: &entries)
            }
        }
    }

    // MARK: - Shortcut

    private static func shortcut(for element: AXUIElement) -> MenuShortcut? {
        guard let char = string(element, kAXMenuItemCmdCharAttribute), !char.isEmpty else {
            return nil
        }
        let modifiers = (attribute(element, kAXMenuItemCmdModifiersAttribute) as? NSNumber)?.intValue ?? 0

        var display = ""
        if modifiers & 8 == 0 {
            display += "⌘"
        }
        if modifiers & 1 != 0 {
            display += "⇧"
        }
        if modifiers & 2 != 0 {
            display += "⌥"
        }
        if modifiers & 4 != 0 {
            display += "⌃"
        }
        display += char.uppercased()
        return MenuShortcut(display: display, keyChar: char, modifiers: modifiers)
    }

    private static func mark(for element: AXUIElement) -> String? {
        guard let mark = string(element, kAXMenuItemMarkCharAttribute), !mark.isEmpty else {
            return nil
        }
        return mark
    }

    private static func markKind(in elements: [AXUIElement]) -> MenuMarkKind {
        var hasCheck = false
        var hasRadio = false
        for element in elements {
            guard let mark = mark(for: element) else { continue }
            if mark == "•" {
                hasRadio = true
            } else if mark == "✓" || mark == "–" {
                hasCheck = true
            }
        }
        if hasRadio {
            return .radio
        }
        if hasCheck {
            return .check
        }
        return .none
    }

    // MARK: - AX primitives

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    private static func string(_ element: AXUIElement, _ name: String) -> String? {
        attribute(element, name) as? String
    }

    private static func bool(_ element: AXUIElement, _ name: String) -> Bool? {
        attribute(element, name) as? Bool
    }

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        (attribute(element, kAXChildrenAttribute) as? [AXUIElement]) ?? []
    }

    /// Returns children with empty-title containers (AXMenu) collapsed away.
    private static func flattenedChildren(of element: AXUIElement) -> [AXUIElement] {
        var result: [AXUIElement] = []
        for child in children(of: element) {
            let title = string(child, kAXTitleAttribute) ?? ""
            if title.isEmpty, !children(of: child).isEmpty {
                result.append(contentsOf: children(of: child))
            } else {
                result.append(child)
            }
        }
        return result
    }

    private static func element(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = attribute(element, name) else {
            return nil
        }
        // swiftlint:disable:next force_cast
        return (value as! AXUIElement)
    }
}
