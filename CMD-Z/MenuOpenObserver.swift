//
//  MenuOpenObserver.swift
//  CMD-Z
//
//  Created by Toni Förster on 17.09.26.
//
//  SPDX-License-Identifier: MIT
//  Copyright (c) 2026 Toni Förster
//

import ApplicationServices
import Cocoa

/// Observes `kAXMenuOpenedNotification` for a target app so callers can invalidate
/// locally tracked menu state once the real menu is opened (which triggers validation).
final class MenuOpenObserver: @unchecked Sendable {
    private let observer: AXObserver
    private let runLoopSource: CFRunLoopSource
    private let pid: pid_t
    private let onMenuOpened: @MainActor () -> Void

    init?(pid: pid_t, onMenuOpened: @escaping @MainActor () -> Void) {
        self.pid = pid
        self.onMenuOpened = onMenuOpened

        var observer: AXObserver?
        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            let selfRef = Unmanaged<MenuOpenObserver>.fromOpaque(refcon).takeUnretainedValue()
            MainActor.assumeIsolated {
                selfRef.onMenuOpened()
            }
        }
        guard AXObserverCreate(pid, callback, &observer) == .success, let observer else {
            return nil
        }
        self.observer = observer
        runLoopSource = AXObserverGetRunLoopSource(observer)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)

        let app = AXUIElementCreateApplication(pid)
        AXObserverAddNotification(
            observer,
            app,
            kAXMenuOpenedNotification as CFString,
            Unmanaged.passUnretained(self).toOpaque()
        )
    }

    deinit {
        CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .defaultMode)
        let app = AXUIElementCreateApplication(pid)
        AXObserverRemoveNotification(observer, app, kAXMenuOpenedNotification as CFString)
    }
}
