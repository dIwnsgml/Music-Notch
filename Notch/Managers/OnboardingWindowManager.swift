import Cocoa
import SwiftUI

class OnboardingWindowManager {
    static let shared = OnboardingWindowManager()
    private var window: NSWindow?

    func showIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.show(reset: true)
        }
    }
    
    func show(reset: Bool = false) {
        if window == nil {
            let hostingController = NSHostingController(rootView: OnboardingView())
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 720, height: 560),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window?.center()
            window?.contentViewController = hostingController
            window?.isReleasedWhenClosed = false
            window?.titleVisibility = .hidden
            window?.titlebarAppearsTransparent = true
            window?.standardWindowButton(.zoomButton)?.isHidden = true
            window?.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window?.level = .floating
        } else if reset {
            window?.contentViewController = NSHostingController(rootView: OnboardingView())
        }
        
        // ⚡️ CRITICAL for Menu Bar apps: Forces the window to the front
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
    
    func close() {
        window?.close()
    }
}
