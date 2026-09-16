//
//  AccessibilityChecker.swift
//  CMD-Z
//
//  Created by Toni Förster on 19.03.25.
//
//  SPDX-License-Identifier: MIT
//  Copyright (c) 2025 Toni Förster
//

import ApplicationServices
import Cocoa

@objc class AccessibilityChecker: NSObject {
    @objc static let shared = AccessibilityChecker()

    /// Returns true if the app is trusted for accessibility features.
    @objc var isAccessibilityEnabled: Bool {
        AXIsProcessTrusted()
    }

    /// Returns true if the app is in the accessibility list but not enabled.
    @objc var isAppInAccessibilityList: Bool {
        let isTrusted = AXIsProcessTrusted()
        let wasPromptedBefore = UserDefaults.standard.bool(forKey: "wasPromptedBefore")

        return !isTrusted && wasPromptedBefore
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
            UserDefaults.standard.set(true, forKey: "wasPromptedBefore")

            self.presentAlert(
                title: NSLocalizedString(
                    "Accessibility Access Required",
                    comment: "Alert title for initial accessibility permission"
                ),
                message: NSLocalizedString(
                    """
                    CMD-Z requires permission in Privacy & Security Settings.

                    Click “Continue” to grant access when prompted.
                    """,
                    comment: "First-time alert message"
                ),
                actionTitle: NSLocalizedString("Continue", comment: "Button title to proceed"),
                action: completion
            )
        }
    }

    @objc func showManualEnableAlert() {
        DispatchQueue.main.async {
            self.presentAlert(
                title: NSLocalizedString(
                    "Accessibility Access Required",
                    comment: "Alert title when access is disabled or denied"
                ),
                message: NSLocalizedString(
                    """
                    CMD-Z requires permission in Privacy & Security Settings.

                    If CMD-Z is missing, add it using the “+” button below the list.
                    """,
                    comment: "Manual alert message"
                ),
                actionTitle: NSLocalizedString("Open Settings", comment: "Button to open System Settings"),
                action: self.openAccessibilitySettings
            )
        }
    }

    /// Shared alert presentation for accessibility-related prompts.
    private func presentAlert(title: String,
                              message: String,
                              actionTitle: String,
                              action: @escaping () -> Void)
    {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: actionTitle)
        alert.addButton(withTitle: NSLocalizedString("Quit", comment: "Quit button title"))

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            action()
        } else if response == .alertSecondButtonReturn {
            AppDelegate.shared?.quitApp()
        }
    }
}
