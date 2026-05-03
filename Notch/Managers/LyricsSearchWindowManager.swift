import AppKit
import SwiftUI

class LyricsSearchWindowManager {
    static let shared = LyricsSearchWindowManager()
    private var window: NSWindow?

    func show(nowPlaying: NowPlayingManager = .shared) {
        DispatchQueue.main.async {
            if let window = self.window {
                window.contentView = NSHostingView(rootView: LyricsSearchView(nowPlaying: nowPlaying))
                if window.isMiniaturized {
                    window.deminiaturize(nil)
                }
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                return
            }

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Lyrics Search"
            window.center()
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 680, height: 500)
            window.contentView = NSHostingView(rootView: LyricsSearchView(nowPlaying: nowPlaying))

            self.window = window
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }

    func close() {
        DispatchQueue.main.async {
            self.window?.close()
        }
    }
}
