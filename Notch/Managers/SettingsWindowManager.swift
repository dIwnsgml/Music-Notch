import Foundation
import AppKit
import SwiftUI

// ⚡️ THE BULLETPROOF SETTINGS MANAGER
class SettingsWindowManager {
    static let shared = SettingsWindowManager()
    private var settingsWindow: NSWindow?

    func showSettings() {
        // If it's already open, just bring it to the front
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // Otherwise, create a brand new native Mac window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 450),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "WaveNotch Settings"
        window.center()
        window.isReleasedWhenClosed = false // Keeps it in memory when closed
        
        // Put our SwiftUI View inside the window
        window.contentView = NSHostingView(rootView: SettingsView())

        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
