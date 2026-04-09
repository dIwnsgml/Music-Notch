import SwiftUI
import AppKit
import SkyLightWindow // ⚡️ The magic package is officially linked!

@main
struct DynamicIslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Keeps the app alive as a background utility
        MenuBarExtra("Island", systemImage: "music.note") {
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

class IslandPanel: NSPanel {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: IslandPanel!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let contentView = ContentView()
        let panelWidth: CGFloat = 400
        let panelHeight: CGFloat = 200
        
        panel = IslandPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow],
            backing: .buffered,
            defer: false
        )

        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
        
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovable = false

        // Anchor Top Center
        if let screen = NSScreen.main {
            let x = (screen.frame.width - panelWidth) / 2
            let y = screen.frame.height - panelHeight
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.contentView = NSHostingView(rootView: contentView)
        
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        
        // ⚡️ THE FINAL FIX:
        // The package only requires the panel itself to inject it into the SkyLight framework.
        _ = SkyLightOperator.shared.delegateWindow(panel)
    }
}
