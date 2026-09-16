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

@MainActor
class AccessibilityChecker {
    static let shared = AccessibilityChecker()

    /// Returns true if the app is trusted for accessibility features.
    var isAccessibilityEnabled: Bool {
        AXIsProcessTrusted()
    }

    /// Returns true if the app is in the accessibility list but not enabled.
    var isAppInAccessibilityList: Bool {
        let isTrusted = AXIsProcessTrusted()
        let wasPromptedBefore = UserDefaults.standard.bool(forKey: "wasPromptedBefore")

        return !isTrusted && wasPromptedBefore
    }

    /// Opens the Accessibility settings in System Preferences.
    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// Presents an alert informing the user that accessibility access is required.
    func showAccessibilityAlert(completion: @escaping () -> Void) {
        UserDefaults.standard.set(true, forKey: "wasPromptedBefore")

        presentAlert(
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

    func showManualEnableAlert() {
        presentAlert(
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
            action: openAccessibilitySettings
        )
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
