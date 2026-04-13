import SwiftUI
import AppKit
import SkyLightWindow // ⚡️ The magic package for floating over the macOS Notch

@main
struct DynamicIslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Keeps the app alive in the menu bar as a background utility
        MenuBarExtra("WaveNotch", systemImage: "music.note") {
            Button("Settings...") {
                SettingsWindowManager.shared.showSettings()
            }
            Divider()
            Button("Quit WaveNotch") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

// ---------------------------------------------------------
// ⚡️ CUSTOM PANEL
// By default, borderless AppKit windows cannot receive keyboard/mouse clicks.
// Overriding these two properties forces macOS to let us click the Notch!
// ---------------------------------------------------------
class IslandPanel: NSPanel {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: IslandPanel!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        // ---------------------------------------------------------
        // ⚡️ THE FIX: We increase the canvas size to 600x350!
        // This gives the SwiftUI view plenty of room to expand to 460px
        // without hitting the walls and getting pushed off-center.
        // ---------------------------------------------------------
        let panelWidth: CGFloat = 600
        let panelHeight: CGFloat = 350
        
        // 2. Create the raw, unstyled window
        panel = IslandPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            // We specifically avoid .hudWindow so macOS doesn't paint a grey background over our app
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        // 3. Configure window behavior for a native "Utility" feel
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.level = .statusBar
        panel.collectionBehavior = [
            .canJoinAllSpaces,      // Shows up on every desktop space
            .stationary,            // Doesn't move when swiping Mission Control
            .ignoresCycle,          // Doesn't clutter up the Cmd+Tab menu
            .fullScreenAuxiliary    // Floats over full-screen apps and games!
        ]
        
        // 4. Make the window physically invisible to let SwiftUI handle the visuals
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovable = false
        
        // 5. Anchor it to the exact Top-Center of the screen
        if let screen = NSScreen.main {
            let x = (screen.frame.width - panelWidth) / 2
            let y = screen.frame.height - panelHeight
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        // 6. Inject our SwiftUI ContentView
        let hostingView = NSHostingView(rootView: ContentView())
        hostingView.wantsLayer = true
        // Explicitly tells the SwiftUI container to be completely see-through
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        
        panel.contentView = hostingView
        
        // 7. Wake the window up
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        
        // 8. ⚡️ THE MAGIC: Inject into macOS WindowServer
        _ = SkyLightOperator.shared.delegateWindow(panel)
    }
}
