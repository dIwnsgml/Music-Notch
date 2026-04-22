import SwiftUI
import AppKit
import SkyLightWindow
import Sparkle
import PostHog

@main
struct DynamicIslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // ⚡️ PostHog Privacy Toggle
    @AppStorage("enableAnalytics") var enableAnalytics = true
    
    // ⚡️ Onboarding Tracker
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    
    init() {
        // 1. Configure PostHog
        let configuration = PostHogConfig(
            apiKey: "phc_tptR6JFYUrtWPDsY4Mo2rZNF9BHnUduUirV58uaLpAjT",
            host: "https://us.i.posthog.com"
        )
        
        // 2. Start the engine
        PostHogSDK.shared.setup(configuration)
        
        // 3. Opt the user out immediately if they disabled it in settings
        if !enableAnalytics {
            PostHogSDK.shared.optOut()
        } else {
            PostHogSDK.shared.optIn()
            PostHogSDK.shared.capture("App Launched")
        }
        
        // ⚡️ 4. Check if it's the user's first time opening the app
        if !hasCompletedOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                OnboardingWindowManager.shared.show()
            }
        }
    }
    
    var body: some Scene {
        MenuBarExtra("WaveNotch", systemImage: "music.note") {
            Button("Settings...") {
                SettingsWindowManager.shared.showSettings()
            }
            
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
    let updaterController: SPUStandardUpdaterController
    
    override init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        super.init()
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        let panelWidth: CGFloat = 800
        let panelHeight: CGFloat = 600
        
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
        
        // ⚡️ Listen for manual centering requests from SwiftUI
        NotificationCenter.default.addObserver(forName: NSNotification.Name("CenterApp"), object: nil, queue: .main) { _ in
            self.centerPanel()
        }
    }
    
    func centerPanel() {
        guard let screen = NSScreen.main else { return }
        let x = (screen.frame.width - panel.frame.width) / 2
        let y = screen.frame.height - panel.frame.height
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
