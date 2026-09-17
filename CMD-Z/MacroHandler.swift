//
//  MacroHandler.swift
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

@MainActor
final class MacroHandler {
    static let shared = MacroHandler()

    /// Marks synthetic events so the event tap passes them through untouched.
    static let syntheticTag: Int64 = 0x434D_445A

    /// Opens Spotlight using the user's actual shortcut, then the clipboard manager (Cmd+4).
    func triggerClipboardManager() {
        let shortcut = Self.spotlightShortcut() ?? (CGKeyCode(kVK_Space), CGEventFlags.maskCommand)
        postKey(shortcut.keyCode, keyDown: true, flags: shortcut.flags)
        postKey(shortcut.keyCode, keyDown: false, flags: shortcut.flags)

        Task { @MainActor [weak self] in
            await self?.waitForSpotlight()
            self?.postKey(CGKeyCode(kVK_ANSI_4), keyDown: true, flags: .maskCommand)
            self?.postKey(CGKeyCode(kVK_ANSI_4), keyDown: false, flags: .maskCommand)
        }
    }

    /// Reads the user's Spotlight shortcut from `com.apple.symbolichotkeys`.
    private static func spotlightShortcut() -> (keyCode: CGKeyCode, flags: CGEventFlags)? {
        let domain = UserDefaults.standard.persistentDomain(forName: "com.apple.symbolichotkeys")
        guard let domain,
              let hotKeys = domain["AppleSymbolicHotKeys"] as? [String: Any],
              let entry = hotKeys["64"] as? [String: Any],
              entry["enabled"] as? Bool == true,
              let value = entry["value"] as? [String: Any],
              let params = value["parameters"] as? [Any],
              params.count >= 3,
              let keyCode = (params[1] as? NSNumber)?.intValue,
              let modifiers = (params[2] as? NSNumber)?.intValue
        else {
            return nil
        }

        var flags: CGEventFlags = []
        if modifiers & 0x020000 != 0 {
            flags.insert(.maskShift)
        }
        if modifiers & 0x040000 != 0 {
            flags.insert(.maskControl)
        }
        if modifiers & 0x080000 != 0 {
            flags.insert(.maskAlternate)
        }
        if modifiers & 0x100000 != 0 {
            flags.insert(.maskCommand)
        }
        return (CGKeyCode(keyCode), flags)
    }

    /// Polls until Spotlight's popover is visible, with a timeout fallback.
    private func waitForSpotlight() async {
        // Spotlight can't be visible this early; skip wasted polls
        try? await Task.sleep(nanoseconds: 20_000_000)

        for _ in 0 ..< 40 {
            if Self.isSpotlightVisible() {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    /// Returns true if the Spotlight process has a visible window.
    private static func isSpotlightVisible() -> Bool {
        let pid = NSWorkspace.shared.runningApplications
            .first { $0.bundleIdentifier == "com.apple.Spotlight" }?
            .processIdentifier
        guard let pid else {
            return false
        }

        let app = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef)
        guard status == .success, let windows = windowsRef as? [AXUIElement] else {
            return false
        }
        return !windows.isEmpty
    }

    private func postKey(_ keyCode: CGKeyCode, keyDown: Bool, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown) else {
            return
        }
        event.flags = flags
        event.setIntegerValueField(.eventSourceUserData, value: Self.syntheticTag)
        event.post(tap: .cghidEventTap)
    }
}
