import SwiftUI
import AppKit

@main
struct MacIslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings { EmptyView() }
    }
}

class InteractionPanel: NSPanel {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
    override var acceptsFirstResponder: Bool { return true }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var notchWindow: InteractionPanel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = ContentView()

        notchWindow = InteractionPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        notchWindow.isOpaque = false
        notchWindow.backgroundColor = .clear
        notchWindow.hasShadow = false
        
        // Stays permanently above Fullscreen apps, games, and the menu bar
        notchWindow.level = .screenSaver
        notchWindow.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        
        notchWindow.contentView = NSHostingView(rootView: contentView)
        notchWindow.makeKeyAndOrderFront(nil)
        
        if let screen = NSScreen.main {
            let screenRect = screen.frame
            let x = screenRect.midX - (notchWindow.frame.width / 2)
            
            // ⚡️ ABSOLUTE TOP PIXEL: Anchors the invisible canvas to the exact top edge of the screen hardware
            let y = screenRect.maxY - notchWindow.frame.height
            notchWindow.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}
