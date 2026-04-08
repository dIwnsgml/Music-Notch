import SwiftUI

@main
struct NotchApp: App {
    // Hide the standard window and use our custom AppDelegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
class AppDelegate: NSObject, NSApplicationDelegate {
    // 1. Change this from NSWindow to NSPanel
    var window: NSPanel!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let contentView = ContentView()

        // 2. Create the NSPanel with a ".nonactivatingPanel" style.
        // This is the magic word that tells macOS: "Don't steal focus from Chrome!"
        window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        
        // Added .ignoresCycle so your Notch doesn't show up when you press Cmd+Tab
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        
        window.contentView = NSHostingView(rootView: contentView)

        if let screen = NSScreen.main {
            let screenWidth = screen.visibleFrame.width
            let screenMaxY = screen.frame.maxY
            
            let width: CGFloat = 400
            let height: CGFloat = 100
            let x = (screenWidth / 2) - (width / 2)
            let y = screenMaxY - height + 10
            
            window.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        }

        // 3. Just order it to the front, don't force it to become the Key window
        window.orderFront(nil)
    }
}
