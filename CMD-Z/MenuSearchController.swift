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
    private var markOverrides: [String: String] = [:]
    private var menuObserver: MenuOpenObserver?
    private var observedPID: pid_t?
    private var overlayMonitor: Task<Void, Never>?

    private init() {
        panel.onSelect = { [weak self] entry in
            self?.trigger(entry)
        }
        panel.onHide = { [weak self] in
            self?.stopOverlayMonitor()
            self?.restoreFocus()
        }
        panel.onExternalDismiss = { [weak self] in
            self?.dismiss()
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
        panel.show(appIcon: NSRunningApplication(processIdentifier: pid)?.icon)
        startOverlayMonitor()

        if pid != observedPID {
            markOverrides.removeAll()
            menuObserver = MenuOpenObserver(pid: pid) { [weak self] in
                self?.markOverrides.removeAll()
            }
            observedPID = pid
        }

        let pidValue = pid
        Task.detached {
            let entries = MenuSearchScanner.entries(for: pidValue)
            await MainActor.run { [weak self] in
                guard let self else { return }
                panel.setEntries(applyOverrides(to: entries))
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
        recordOverride(for: entry)
        panel.hide()
        frontmostPID = nil

        let pidValue = pid
        Task.detached {
            _ = MenuSearchScanner.trigger(path: path, pid: pidValue)
        }
    }

    private func recordOverride(for entry: MenuEntry) {
        switch entry.markKind {
        case .none:
            break
        case .check:
            markOverrides[entry.pathKey] = entry.mark == "✓" ? "" : "✓"
        case .radio:
            markOverrides[entry.pathKey] = "•"
        }
    }

    private func applyOverrides(to entries: [MenuEntry]) -> [MenuEntry] {
        guard !markOverrides.isEmpty else { return entries }
        return entries.map { entry in
            guard let value = markOverrides[entry.pathKey] else { return entry }
            let mark: String? = value.isEmpty ? nil : value
            return MenuEntry(
                title: entry.title,
                path: entry.path,
                shortcut: entry.shortcut,
                mark: mark,
                markKind: entry.markKind,
                enabled: entry.enabled
            )
        }
    }

    private func restoreFocus() {
        guard let pid = frontmostPID else {
            return
        }
        NSRunningApplication(processIdentifier: pid)?.activate()
    }

    func dismiss() {
        guard panel.isVisible else { return }
        frontmostPID = nil
        panel.hide()
    }

    private func startOverlayMonitor() {
        overlayMonitor?.cancel()
        overlayMonitor = Task.detached { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 200_000_000)
                if Task.isCancelled {
                    return
                }
                let visible = await MainActor.run { self?.panel.isVisible ?? false }
                if !visible {
                    return
                }
                if MacroHandler.isSpotlightVisible() {
                    await MainActor.run { self?.dismiss() }
                    return
                }
            }
        }
    }

    private func stopOverlayMonitor() {
        overlayMonitor?.cancel()
        overlayMonitor = nil
    }
}
