import SwiftUI
import AppKit
import SkyLightWindow
import Sparkle
import PostHog

@main
struct DynamicIslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @AppStorage("enableAnalytics") var enableAnalytics = true
    
    init() {
        let configuration = PostHogConfig(
            apiKey: "phc_tptR6JFYUrtWPDsY4Mo2rZNF9BHnUduUirV58uaLpAjT",
            host: "https://us.i.posthog.com"
        )
        PostHogSDK.shared.setup(configuration)
        
        if !enableAnalytics {
            PostHogSDK.shared.optOut()
        } else {
            PostHogSDK.shared.optIn()
            PostHogSDK.shared.capture("App Launched")
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

// ⚡️ URL Handling for OAuth
struct URLHandler: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onOpenURL { url in
                print("Received URL: \(url.absoluteString)")
                
                if url.scheme == "wavenotch" {
                    if url.host == "callback" {
                        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                           let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                            NotificationCenter.default.post(name: NSNotification.Name("SpotifyAuthCallback"), object: code)
                        }
                    }
                } else if url.scheme == "com.googleusercontent.apps.989490326013-4ukfahi6t9cplb3mujovrrbtb1onoif0" {
                    if url.path == "/google-callback" {
                        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                           let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                            NotificationCenter.default.post(name: NSNotification.Name("GoogleAuthCallback"), object: code)
                        }
                    }
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
        
        // ⚡️ Large transparent window to allow dynamic sizing of content within it
        let panelWidth: CGFloat = 1000 
        let panelHeight: CGFloat = 800
        
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
        
        let hostingView = NSHostingView(rootView: ContentView().modifier(URLHandler()))
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        
        panel.contentView = hostingView
        
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        
        _ = SkyLightOperator.shared.delegateWindow(panel)
        
        // ⚡️ Initial center
        centerPanel()
        
        // ⚡️ Listen for layout changes to re-center the window
        NotificationCenter.default.addObserver(forName: NSNotification.Name("CenterAppWindow"), object: nil, queue: .main) { _ in
            self.centerPanel()
        }
    }
    
    func centerPanel() {
        guard let screen = NSScreen.main else { return }
        let x = screen.frame.origin.x + (screen.frame.width - panel.frame.width) / 2
        let y = screen.frame.maxY - panel.frame.height
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
