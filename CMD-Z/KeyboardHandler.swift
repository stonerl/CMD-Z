//
//  KeyboardHandler.swift
//  CMD-Z
//
//  Created by Toni Förster on 18.03.25.
//
//  SPDX-License-Identifier: MIT
//  Copyright (c) 2025 Toni Förster
//

import Carbon
import Cocoa
import OSLog

private let logger = Logger(subsystem: "de.fauler-apfel.CMD-Z", category: "KeyboardHandler")

class KeyboardHandler {
    /// Returns the current keyboard layout ID using the Carbon TIS API.
    static func currentKeyboardLayoutID() -> String? {
        guard let inputSource = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue() else {
            return nil
        }
        if let sourceID = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceID) {
            return unsafeBitCast(sourceID, to: CFString.self) as String
        }
        return nil
    }

    /// Checks if the current keyboard layout is one of the allowed layouts.
    static func isAllowedKeyboardLayout() -> Bool {
        let allowedLayouts: Set<String> = [
            "com.apple.keylayout.ABC-QWERTZ",
            "com.apple.keylayout.Albanian",
            "com.apple.keylayout.Austrian",
            "com.apple.keylayout.Croatian-PC",
            "com.apple.keylayout.Czech",
            "com.apple.keylayout.German",
            "com.apple.keylayout.German-DIN-2137",
            "com.apple.keylayout.Hungarian",
            "com.apple.keylayout.Slovak",
            "com.apple.keylayout.SwissFrench",
            "com.apple.keylayout.SwissGerman"
        ]
        guard let layoutID = currentKeyboardLayoutID() else { return false }
        return allowedLayouts.contains(layoutID)
    }

    /// Checks if the frontmost app is an app that uses Windows style shortcuts for Redo (CMD+Y).
    static func hasWindowsShortcut() -> Bool {
        if let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier {
            logger.debug("Frontmost application: \(bundleId)")
            if bundleId.hasPrefix("com.microsoft.") {
                return bundleId == "com.microsoft.Word" ||
                    bundleId == "com.microsoft.Excel" ||
                    bundleId == "com.microsoft.PowerPoint" ||
                    bundleId == "com.microsoft.Outlook" ||
                    bundleId == "com.microsoft.onenote.mac"
            } else {
                return bundleId == "org.libreoffice.script"
            }
        }
        return false
    }

    /// Handles a key event by performing remapping based on the current layout and target application.
    static func handleCGEvent(type _: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Access isRemappingEnabled from AppDelegate (assumes AppDelegate.shared is available)
        guard let isRemappingEnabled = AppDelegate.shared?.isRemappingEnabled, isRemappingEnabled else {
            return Unmanaged.passUnretained(event)
        }

        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let allowedLayout = isAllowedKeyboardLayout()
        let windowsShortcut = hasWindowsShortcut()

        // If the current layout is not allowed...
        if !allowedLayout {
            // ...and we're in an app with Windows style shortcuts, then if Command+Shift+Z is pressed,
            // remove the Shift modifier and remap to Command+Y.
            if windowsShortcut, flags.contains(.maskCommand), flags.contains(.maskShift), keyCode == 6 {
                event.flags.remove(.maskShift)
                event.setIntegerValueField(.keyboardEventKeycode, value: 16)
            }
            return Unmanaged.passUnretained(event)
        }

        // For allowed keyboard layouts, perform full remapping.
        if flags.contains(.maskCommand) {
            // Special case: For apps with Windows style shortcuts, if Command+Shift+Y is pressed, remove Shift.
            if windowsShortcut, flags.contains(.maskShift), keyCode == 16 {
                event.flags.remove(.maskShift)
                return Unmanaged.passUnretained(event)
            }

            // For both all apps, swap 'Z' (key code 6) and 'Y' (key code 16).
            if keyCode == 6 || keyCode == 16 {
                event.setIntegerValueField(.keyboardEventKeycode, value: keyCode == 6 ? 16 : 6)
            }
        }

        return Unmanaged.passUnretained(event)
    }
}
