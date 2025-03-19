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

    /// Presents an alert informing the user that accessibility access is required.
    @objc func showAccessibilityAlert(completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString(
                "Accessibility Access Required",
                comment: "Alert title for missing accessibility access"
            )
            alert.informativeText = NSLocalizedString(
                """
                CMD-Z requires accessibility access to function properly.

                Please grant access in System Settings.
                """,
                comment: "Alert message"
            )
            alert.addButton(withTitle: NSLocalizedString(
                "Open Settings",
                comment: "Button title to open privacy settings"
            ))
            alert.addButton(withTitle: NSLocalizedString(
                "Quit", comment: "Quit button title"
            ))

            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                self.openAccessibilitySettings()
            } else if response == .alertSecondButtonReturn {
                AppDelegate.shared?.quitApp()
            }

            completion() // Notify that user made a decision
        }
    }
}
