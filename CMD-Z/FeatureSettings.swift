//
//  FeatureSettings.swift
//  CMD-Z
//
//  Created by Toni Förster on 17.09.26.
//
//  SPDX-License-Identifier: MIT
//  Copyright (c) 2026 Toni Förster
//

import Foundation

/// Bool flag backed by UserDefaults; `defaultValue` applies when the key was never written.
@propertyWrapper
struct StoredFlag {
    private let key: String
    private let defaultValue: Bool

    init(_ key: String, default defaultValue: Bool) {
        self.key = key
        self.defaultValue = defaultValue
    }

    var wrappedValue: Bool {
        get {
            if UserDefaults.standard.object(forKey: key) == nil {
                return defaultValue
            }
            return UserDefaults.standard.bool(forKey: key)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}

/// Single owner of all persisted feature settings.
@MainActor
enum FeatureSettings {
    @StoredFlag("isRemappingEnabled", default: true)
    static var isRemappingEnabled

    @StoredFlag("isHyperKeyEnabled", default: true)
    static var isHyperKeyEnabled

    @StoredFlag("isClipboardMacroEnabled", default: true)
    static var isClipboardMacroEnabled

    @StoredFlag("isMenuSearchEnabled", default: true)
    static var isMenuSearchEnabled

    @StoredFlag("wasPromptedBefore", default: false)
    static var wasPromptedBefore

    static var recentMenuPaths: [String] {
        get { UserDefaults.standard.stringArray(forKey: "recentMenuPaths") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "recentMenuPaths") }
    }
}
