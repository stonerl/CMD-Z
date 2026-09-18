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
import Carbon
import Cocoa

/// The key equivalent of a menu item, kept raw enough to match against a real key event.
struct MenuShortcut: Sendable, Equatable {
    let keyChar: String
    let modifiers: Int
    let symbolName: String?

    /// Carbon `MenuCommandModifiers` bits: 1=⇧, 2=⌥, 4=⌃, 8=no-⌘, 0x10=fn.
    func matches(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags
        let wantsCommand = (modifiers & 8) == 0
        guard flags.contains(.command) == wantsCommand,
              flags.contains(.shift) == ((modifiers & 1) != 0),
              flags.contains(.option) == ((modifiers & 2) != 0),
              flags.contains(.control) == ((modifiers & 4) != 0),
              flags.contains(.function) == ((modifiers & 0x10) != 0)
        else {
            return false
        }
        guard let eventChar = event.charactersIgnoringModifiers?.lowercased(), !eventChar.isEmpty else {
            return false
        }
        return eventChar == keyChar.lowercased()
    }
}

/// Character values the Accessibility API uses for key glyphs.
enum AXGlyph {
    static let globe = "\u{1F310}" // globe / function key
    static let microphone = "\u{1F3A4}" // dictation key
}

/// A single searchable menu item, represented as Sendable value types so it can cross actors.
struct MenuEntry: Sendable, Equatable {
    let title: String
    let path: [String]
    let indices: [Int]
    let shortcut: MenuShortcut?
    let enabled: Bool

    var displayPath: String {
        path.joined(separator: " > ")
    }

    var pathKey: String {
        zip(path, indices).map { "\($0)\u{2}\($1)" }.joined(separator: "\u{1}")
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

        // Skip the global Apple menu (AX reports its title as "Apple").
        for (index, item) in children(of: menuBar).enumerated() {
            guard let raw = string(item, kAXTitleAttribute), !raw.isEmpty, raw != "Apple" else {
                continue
            }
            let title = normalizeTitle(raw)
            walk(item, path: [title], indices: [index], deadline: deadline, into: &result)
        }
        return result
    }

    /// Triggers the menu item at `path` by resolving its leaf element and pressing it directly.
    static func trigger(path: [String], indices: [Int], pid: pid_t) -> Bool {
        Thread.sleep(forTimeInterval: 0.15)

        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.5)

        guard let menuBar = element(app, kAXMenuBarAttribute) else {
            return false
        }

        guard indices.count == path.count else {
            return false
        }

        var items = children(of: menuBar)
        var leaf: AXUIElement?
        for (level, title) in path.enumerated() {
            let target = indices[level]
            let match: AXUIElement? = if items.indices.contains(target),
                                         normalizeTitle(string(items[target], kAXTitleAttribute) ?? "") == title
            {
                items[target]
            } else {
                items.first(where: { normalizeTitle(string($0, kAXTitleAttribute) ?? "") == title })
            }
            guard let match else {
                return false
            }
            leaf = match
            if level < path.count - 1 {
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
                             indices: [Int],
                             deadline: Date,
                             into entries: inout [MenuEntry])
    {
        guard Date() < deadline else { return }

        let children = flattenedChildren(of: element)

        for (childIndex, child) in children.enumerated() {
            guard Date() < deadline else { return }
            AXUIElementSetMessagingTimeout(child, sweepTimeout)

            let title = normalizeTitle(string(child, kAXTitleAttribute) ?? "")
            let nested = flattenedChildren(of: child)

            if nested.isEmpty {
                if !title.isEmpty {
                    entries.append(MenuEntry(
                        title: title,
                        path: path + [title],
                        indices: indices + [childIndex],
                        shortcut: shortcut(for: child),
                        enabled: bool(child, kAXEnabledAttribute) ?? true
                    ))
                }
            } else {
                walk(child, path: path + [title], indices: indices + [childIndex], deadline: deadline, into: &entries)
            }
        }
    }

    // MARK: - Shortcut

    private static func shortcut(for element: AXUIElement) -> MenuShortcut? {
        guard let char = string(element, kAXMenuItemCmdCharAttribute), !char.isEmpty else {
            return nil
        }
        let modifiers = (attribute(element, kAXMenuItemCmdModifiersAttribute) as? NSNumber)?.intValue ?? 0
        let virtualKey = (attribute(element, kAXMenuItemCmdVirtualKeyAttribute) as? NSNumber)?.intValue
        return MenuShortcut(
            keyChar: char,
            modifiers: modifiers,
            symbolName: symbolName(forChar: char, virtualKey: virtualKey)
        )
    }

    private static let virtualKeySymbols: [Int: String] = [
        kVK_Return: "return",
        kVK_ANSI_KeypadEnter: "return",
        kVK_Tab: "arrow.right.to.line",
        kVK_Space: "space",
        kVK_Delete: "delete.left",
        kVK_ForwardDelete: "delete.right",
        kVK_Escape: "escape",
        kVK_CapsLock: "capslock",
        kVK_Home: "arrow.up.to.line",
        kVK_End: "arrow.down.to.line",
        kVK_PageUp: "arrow.up.to.line.alt",
        kVK_PageDown: "arrow.down.to.line.alt",
        kVK_UpArrow: "arrowtriangle.up.fill",
        kVK_DownArrow: "arrowtriangle.down.fill",
        kVK_LeftArrow: "arrowtriangle.left.fill",
        kVK_RightArrow: "arrowtriangle.right.fill"
    ]

    private static func symbolName(forChar char: String, virtualKey: Int?) -> String? {
        if char == AXGlyph.globe {
            return "globe"
        }
        if char == AXGlyph.microphone {
            return "mic"
        }
        if char == "\u{7F}" {
            return "delete.right"
        }
        guard let virtualKey else {
            return nil
        }
        return virtualKeySymbols[virtualKey]
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

    private static func normalizeTitle(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
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
