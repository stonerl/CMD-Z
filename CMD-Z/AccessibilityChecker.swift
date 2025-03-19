//
//  AccessibilityChecker.swift
//  CMD-Z
//
//  Created by Toni Förster on 19.03.25.
//

import ApplicationServices
import Cocoa

@objc class AccessibilityChecker: NSObject {
    @objc static let shared = AccessibilityChecker()

    /// Returns true if the app is trusted for accessibility features.
    @objc var isAccessibilityEnabled: Bool {
        AXIsProcessTrusted()
    }

    /// Opens the Accessibility settings in System Preferences.
    @objc func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
