import SwiftUI
import AppKit
import SkyLightWindow
import Sparkle

@main
struct DynamicIslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Keeps the app alive in the menu bar as a background utility
        MenuBarExtra("WaveNotch", systemImage: "music.note") {
            Button("Settings...") {
                SettingsWindowManager.shared.showSettings()
            }
            
            // ⚡️ THE FIX: Add the Check for Updates button
            Button("Check for Updates...") {
                appDelegate.updaterController.checkForUpdates(nil)
            }
            
            Divider()
            
            Button("Quit WaveNotch") {
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
    
    // ⚡️ THE FIX: Initialize Sparkle's Updater Controller
    let updaterController: SPUStandardUpdaterController
    
    override init() {
        // Starts the updater engine the moment the app launches
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        super.init()
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        let panelWidth: CGFloat = 600
        let panelHeight: CGFloat = 350
        
        panel = IslandPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.level = .statusBar
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
        
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovable = false
        
        if let screen = NSScreen.main {
            let x = (screen.frame.width - panelWidth) / 2
            let y = screen.frame.height - panelHeight
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }
        
        let hostingView = NSHostingView(rootView: ContentView())
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        
        panel.contentView = hostingView
        
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        
        _ = SkyLightOperator.shared.delegateWindow(panel)
    }
}
