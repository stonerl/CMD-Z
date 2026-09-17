//
//  MenuSearchPanel.swift
//  CMD-Z
//
//  Created by Toni Förster on 17.09.26.
//
//  SPDX-License-Identifier: MIT
//  Copyright (c) 2026 Toni Förster
//

import Cocoa

/// A borderless panel that can become the key window even when the app is an accessory.
@MainActor
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}

@MainActor
final class MenuSearchPanel: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    let window: KeyablePanel

    private let searchField = NSTextField()
    private let appIconView = NSImageView()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()

    private var allEntries: [MenuEntry] = []
    private var filteredEntries: [MenuEntry] = []
    private var shortcutMonitor: Any?

    var onSelect: ((MenuEntry) -> Void)?
    var onHide: (() -> Void)?

    override init() {
        window = KeyablePanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()
        configureWindow()
        configureContent()
    }

    // MARK: - Window & content

    private func configureWindow() {
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hidesOnDeactivate = true
    }

    private func configureContent() {
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .menu
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.maskImage = Self.roundedMask(cornerRadius: 16)

        searchField.isBezeled = false
        searchField.drawsBackground = false
        searchField.focusRingType = .none
        searchField.font = NSFont.preferredFont(forTextStyle: .title2)
        searchField.textColor = .labelColor
        searchField.placeholderString = "Search menu items…"
        searchField.delegate = self

        appIconView.imageScaling = .scaleProportionallyDown

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("result"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 48
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = false
        tableView.target = self
        tableView.doubleAction = #selector(handleDoubleClick)

        scrollView.documentView = tableView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        visualEffect.addSubview(searchField)
        visualEffect.addSubview(appIconView)
        visualEffect.addSubview(scrollView)

        searchField.translatesAutoresizingMaskIntoConstraints = false
        appIconView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            appIconView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor, constant: 20),
            appIconView.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            appIconView.widthAnchor.constraint(equalToConstant: 18),
            appIconView.heightAnchor.constraint(equalToConstant: 18),

            searchField.topAnchor.constraint(equalTo: visualEffect.topAnchor, constant: 18),
            searchField.leadingAnchor.constraint(equalTo: appIconView.trailingAnchor, constant: 8),
            searchField.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor, constant: -8)
        ])

        window.contentView = visualEffect
    }

    private static func roundedMask(cornerRadius radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
            NSColor.black.setFill()
            path.fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }

    // MARK: - Show / hide

    var isVisible: Bool {
        window.isVisible
    }

    func show(appIcon: NSImage?) {
        center()
        appIconView.image = appIcon
        NSApp.activate(ignoringOtherApps: true)
        window.orderFrontRegardless()
        window.makeKey()
        searchField.stringValue = ""
        applyFilter()
        window.makeFirstResponder(searchField)
        installShortcutMonitor()
    }

    func hide() {
        window.orderOut(nil)
        removeShortcutMonitor()
        onHide?()
    }

    private func center() {
        guard let screen = NSScreen.main else { return }
        let frame = window.frame
        window.setFrameOrigin(NSPoint(
            x: screen.visibleFrame.midX - frame.width / 2,
            y: screen.visibleFrame.midY - frame.height / 2
        ))
    }

    // MARK: - Shortcut execution

    private func installShortcutMonitor() {
        removeShortcutMonitor()
        shortcutMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let handled = MainActor.assumeIsolated {
                guard let entry = self.entry(matchingShortcut: event) else {
                    return false
                }
                self.onSelect?(entry)
                return true
            }
            return handled ? nil : event
        }
    }

    private func removeShortcutMonitor() {
        guard let shortcutMonitor else { return }
        NSEvent.removeMonitor(shortcutMonitor)
        self.shortcutMonitor = nil
    }

    private func entry(matchingShortcut event: NSEvent) -> MenuEntry? {
        for entry in allEntries where entry.enabled {
            if let shortcut = entry.shortcut, shortcut.matches(event) {
                return entry
            }
        }
        return nil
    }

    // MARK: - Data

    func setEntries(_ entries: [MenuEntry]) {
        allEntries = entries
        applyFilter()
    }

    private func applyFilter() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty {
            filteredEntries = allEntries
        } else {
            let scored = allEntries.enumerated().compactMap { index, entry -> ScoredEntry? in
                guard let score = FuzzyMatcher.score(query: query, title: entry.title, path: entry.displayPath) else {
                    return nil
                }
                return ScoredEntry(index: index, score: score, entry: entry)
            }
            filteredEntries = scored
                .sorted { lhs, rhs in
                    if lhs.score == rhs.score {
                        return lhs.index < rhs.index
                    }
                    return lhs.score > rhs.score
                }
                .map(\.entry)
        }
        tableView.reloadData()
        if !filteredEntries.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            tableView.scrollRowToVisible(0)
        }
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in _: NSTableView) -> Int {
        filteredEntries.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
        let entry = filteredEntries[row]
        let identifier = NSUserInterfaceItemIdentifier("cell")

        let cell: MenuCellView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: nil) as? MenuCellView {
            cell = reused
        } else {
            cell = MenuCellView()
            cell.identifier = identifier
        }
        cell.configure(entry: entry)
        return cell
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_: Notification) {
        applyFilter()
    }

    func control(_: NSControl, textView _: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.moveDown(_:)):
            moveSelection(1)
            return true
        case #selector(NSResponder.moveUp(_:)):
            moveSelection(-1)
            return true
        case #selector(NSResponder.insertNewline(_:)):
            triggerSelected()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            hide()
            return true
        default:
            return false
        }
    }

    // MARK: - Interaction

    @objc private func handleDoubleClick() {
        triggerSelected()
    }

    private func moveSelection(_ delta: Int) {
        guard !filteredEntries.isEmpty else { return }
        let current = tableView.selectedRow
        let newRow: Int = if current < 0 {
            delta > 0 ? 0 : filteredEntries.count - 1
        } else {
            min(max(current + delta, 0), filteredEntries.count - 1)
        }
        tableView.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(newRow)
    }

    private func triggerSelected() {
        let row = tableView.selectedRow
        guard row >= 0, row < filteredEntries.count else { return }
        onSelect?(filteredEntries[row])
    }
}

@MainActor
private final class MenuCellView: NSTableCellView {
    private let markLabel = NSTextField(labelWithString: "")
    private let titleLabel = NSTextField(labelWithString: "")
    private let pathLabel = NSTextField(labelWithString: "")
    private let shortcutLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        markLabel.font = NSFont.preferredFont(forTextStyle: .body)
        markLabel.textColor = .secondaryLabelColor

        titleLabel.font = NSFont.preferredFont(forTextStyle: .headline)
        titleLabel.lineBreakMode = .byTruncatingTail

        pathLabel.font = NSFont.preferredFont(forTextStyle: .caption1)
        pathLabel.textColor = .secondaryLabelColor
        pathLabel.lineBreakMode = .byTruncatingTail

        shortcutLabel.font = NSFont.preferredFont(forTextStyle: .body)
        shortcutLabel.textColor = .secondaryLabelColor
        shortcutLabel.alignment = .right

        addSubview(markLabel)
        addSubview(titleLabel)
        addSubview(pathLabel)
        addSubview(shortcutLabel)

        markLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        shortcutLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            markLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            markLabel.widthAnchor.constraint(equalToConstant: 16),
            markLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: markLabel.trailingAnchor, constant: 1),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: shortcutLabel.leadingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 6),

            pathLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            pathLabel.trailingAnchor.constraint(lessThanOrEqualTo: shortcutLabel.leadingAnchor, constant: -8),
            pathLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1),

            shortcutLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            shortcutLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(entry: MenuEntry) {
        markLabel.stringValue = entry.mark ?? ""
        titleLabel.stringValue = entry.title
        pathLabel.stringValue = entry.displayPath
        shortcutLabel.stringValue = entry.shortcut?.display ?? ""
        titleLabel.textColor = entry.enabled ? .labelColor : .secondaryLabelColor
    }
}

private struct ScoredEntry {
    let index: Int
    let score: Double
    let entry: MenuEntry
}
