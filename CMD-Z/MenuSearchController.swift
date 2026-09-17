//
//  MenuSearchController.swift
//  CMD-Z
//
//  Created by Toni Förster on 17.09.26.
//
//  SPDX-License-Identifier: MIT
//  Copyright (c) 2026 Toni Förster
//

import Cocoa

@MainActor
final class MenuSearchController {
    static let shared = MenuSearchController()

    private let panel = MenuSearchPanel()
    private var frontmostPID: pid_t?

    private init() {
        panel.onSelect = { [weak self] entry in
            self?.trigger(entry)
        }
        panel.onHide = { [weak self] in
            self?.restoreFocus()
        }
    }

    var isVisible: Bool {
        panel.isVisible
    }

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            return
        }
        frontmostPID = pid
        panel.show()

        let pidValue = pid
        Task.detached {
            let entries = MenuSearchScanner.entries(for: pidValue)
            await MainActor.run { [weak self] in
                self?.panel.setEntries(entries)
            }
        }
    }

    func hide() {
        panel.hide()
        frontmostPID = nil
    }

    private func trigger(_ entry: MenuEntry) {
        guard let pid = frontmostPID else {
            return
        }
        let path = entry.path
        panel.hide()
        frontmostPID = nil

        let pidValue = pid
        Task.detached {
            _ = MenuSearchScanner.trigger(path: path, pid: pidValue)
        }
    }

    private func restoreFocus() {
        guard let pid = frontmostPID else {
            return
        }
        NSRunningApplication(processIdentifier: pid)?.activate()
    }
}
