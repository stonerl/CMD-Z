//
//  CapsLockRemapper.swift
//  CMD-Z
//
//  Created by Toni Förster on 17.09.26.
//
//  SPDX-License-Identifier: MIT
//  Copyright (c) 2026 Toni Förster
//

import Foundation

enum CapsLockRemapper {
    private static let mappingOn = """
    {"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x700000039,"HIDKeyboardModifierMappingDst":0x70000006D}]}
    """
    private static let mappingOff = """
    {"UserKeyMapping":[]}
    """

    private static let queue = DispatchQueue(label: "de.fauler-apfel.CMD-Z.capslock-remap")

    static func setEnabled(_ enabled: Bool) {
        let mapping = enabled ? mappingOn : mappingOff
        queue.async { apply(mapping) }
    }

    static func clearBlocking() {
        apply(mappingOff)
    }

    private static func apply(_ mapping: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        process.arguments = ["property", "--set", mapping]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            NSLog("CapsLockRemapper: hidutil failed: %@", error.localizedDescription)
        }
    }
}
