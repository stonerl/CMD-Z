//
//  AutostartManager.swift
//  CMD-Z
//
//  Created by Toni Förster on 18.03.25.
//

import Cocoa
import OSLog
import ServiceManagement

class AutostartManager {
    static let shared = AutostartManager()
    private let logger = Logger(subsystem: "de.fauler-apfel.CMD-Z", category: "AutostartManager")

    /// Enables or disables starting the app at login.
    func enableAutostart(_ enable: Bool) {
        let appService = SMAppService.mainApp
        do {
            if enable {
                try appService.register()
                logger.info("Open at Login enabled")
            } else {
                try appService.unregister()
                logger.info("Open at Login disabled")
            }
        } catch {
            logger.error("Failed to update Open at Login setting: \(error.localizedDescription)")

            // Optionally, display an alert if needed:
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("Error", comment: "Alert title for errors")
            alert.informativeText = String(
                format: NSLocalizedString("Failed to update Open at Login setting: %@",
                                          comment: "Error description for autostart update failure"),
                error.localizedDescription
            )
            alert.alertStyle = .warning
            alert.addButton(withTitle: NSLocalizedString("OK", comment: "Alert confirmation button"))
            alert.runModal()
        }
    }
}
