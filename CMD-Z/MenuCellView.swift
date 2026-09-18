//
//  MenuCellView.swift
//  CMD-Z
//
//  Created by Toni Förster on 17.09.26.
//
//  SPDX-License-Identifier: MIT
//  Copyright (c) 2026 Toni Förster
//

import Cocoa

@MainActor
final class MenuCellView: NSTableCellView {
    private static let symbolOvershoot: CGFloat = 1.2
    private static let symbolOvershoots: [String: CGFloat] = ["control": 0.8]
    private static let symbolBaselineOffsets: [String: CGFloat] = ["control": 2]

    private let titleLabel = NSTextField(labelWithString: "")
    private let pathLabel = NSTextField(labelWithString: "")
    private let shortcutLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        titleLabel.font = NSFont.preferredFont(forTextStyle: .headline)
        titleLabel.lineBreakMode = .byTruncatingTail

        pathLabel.font = NSFont.preferredFont(forTextStyle: .caption1)
        pathLabel.textColor = .secondaryLabelColor
        pathLabel.lineBreakMode = .byTruncatingTail

        shortcutLabel.font = NSFont.preferredFont(forTextStyle: .body)
        shortcutLabel.textColor = .secondaryLabelColor
        shortcutLabel.alignment = .right

        addSubview(titleLabel)
        addSubview(pathLabel)
        addSubview(shortcutLabel)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        pathLabel.translatesAutoresizingMaskIntoConstraints = false
        shortcutLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: shortcutLabel.leadingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 6),

            pathLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            pathLabel.trailingAnchor.constraint(lessThanOrEqualTo: shortcutLabel.leadingAnchor, constant: -8),
            pathLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 1),
            pathLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),

            shortcutLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            shortcutLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(entry: MenuEntry) {
        titleLabel.stringValue = entry.title
        pathLabel.stringValue = entry.displayPath
        shortcutLabel.attributedStringValue = entry.shortcut.map(Self.attributedShortcut) ?? NSAttributedString()
    }

    private static func symbolImage(_ name: String) -> NSImage? {
        let size = NSFont.preferredFont(forTextStyle: .body).pointSize
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: size, weight: .regular))
    }

    private static func attributedShortcut(_ shortcut: MenuShortcut) -> NSAttributedString {
        let result = NSMutableAttributedString()
        if shortcut.modifiers & 0x10 != 0 {
            result.append(symbolAttachment("globe"))
        }
        if shortcut.modifiers & 4 != 0 {
            result.append(symbolAttachment("control"))
        }
        if shortcut.modifiers & 2 != 0 {
            result.append(symbolAttachment("option"))
        }
        if shortcut.modifiers & 1 != 0 {
            result.append(symbolAttachment("shift"))
        }
        if shortcut.modifiers & 8 == 0 {
            result.append(symbolAttachment("command"))
        }
        if let symbol = shortcut.symbolName {
            result.append(symbolAttachment(symbol))
        } else {
            result.append(NSAttributedString(string: shortcut.keyChar.uppercased()))
        }
        return result
    }

    private static func symbolAttachment(_ name: String) -> NSAttributedString {
        let attachment = NSTextAttachment()
        if let image = symbolImage(name) {
            let font = NSFont.preferredFont(forTextStyle: .body)
            let height = font.capHeight * (symbolOvershoots[name] ?? symbolOvershoot)
            let width = image.size.width * (height / image.size.height)
            attachment.image = image
            let baselineOffset = (font.capHeight - height) / 2 + (symbolBaselineOffsets[name] ?? 0)
            attachment.bounds = CGRect(x: 0, y: baselineOffset, width: width, height: height)
        }
        return NSAttributedString(attachment: attachment)
    }
}
