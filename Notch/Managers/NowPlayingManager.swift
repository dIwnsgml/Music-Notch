import SwiftUI
import Combine
import AppKit

class NowPlayingManager: ObservableObject {
    // ⚡️ Network Safety & Caching
    var lyricSearchTask: DispatchWorkItem? = nil
    var lyricsCache: [String: [LyricLine]] = [:]
    var currentLyricSearchID: UUID = UUID() // ⚡️ THE TICKET COUNTER
    
    @Published var currentSong: String = "No Music"
    var internalSongIdentifier: String = ""
    
    
    // ⚡️ ADD THIS LINE RIGHT HERE:
    @AppStorage("enableAppleMusic") var enableAppleMusic = false
    @AppStorage("enableSpotify") var enableSpotify = false
    @AppStorage("enableChrome") var enableChrome = false
    @AppStorage("enableBrave") var enableBrave = false
    @AppStorage("enableEdge") var enableEdge = false
    @AppStorage("enableSafari") var enableSafari = false
    
    
    // ⚡️ NEW: Dynamically returns ONLY the browsers the user has approved
    var allowedBrowsers: [String] {
        var list: [String] = []
        if enableChrome { list.append("Google Chrome") }
        if enableBrave { list.append("Brave Browser") }
        if enableEdge { list.append("Microsoft Edge") }
        if enableSafari { list.append("Safari") }
        return list
    }
    
    @Published var artworkURL: URL? = nil
    @Published var artworkDominantColor: Color = .green
    @Published var isPlaying: Bool = false
    @Published var loopMode: Int = 0
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 1.0
    
    @Published var lyrics: [LyricLine] = []
    @Published var activeLyricIndex: Int = 0
    @Published var isSearchingLyrics: Bool = false
    @Published var playlist: [PlaylistTrack] = []
    // ⚡️ NEW: Triggers the UI when a control is used
    @Published var lastControlAction: UUID = UUID()
    
    var timer: Timer?
    var isFetching = false
    var lastFetchTime = Date(timeIntervalSince1970: 0)
    var lastLoopToggleTime = Date(timeIntervalSince1970: 0)
    
    var lastActiveBrowser: String? = nil
    var lastWindowIndex: Int? = nil
    var lastTabIndex: Int? = nil
    
    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.fetchTitle()
        }
    }
    
    // ---------------------------------------------------------
    // ⚡️ THE FIX: Aggressive NSRunningApplication Launcher
    // ---------------------------------------------------------
    func openPlayingApp() {
        DispatchQueue.main.async {
            let runningApps = NSWorkspace.shared.runningApplications
            
            // 1. If Spotify is running, rip it to the front instantly
            if let spotify = runningApps.first(where: { $0.bundleIdentifier == "com.spotify.client" }) {
                spotify.activate(options: .activateIgnoringOtherApps)
                return
            }
            
            // 2. If Apple Music is running, rip it to the front
            if let music = runningApps.first(where: { $0.bundleIdentifier == "com.apple.Music" }) {
                music.activate(options: .activateIgnoringOtherApps)
                return
            }
            
            // 3. Fallback to the active browser
            if let browser = self.lastActiveBrowser {
                self.activateApp(appName: browser)
            }
        }
    }
    
    private func activateApp(appName: String) {
        let bundleID: String
        switch appName {
        case "Safari": bundleID = "com.apple.Safari"
        case "Google Chrome": bundleID = "com.google.Chrome"
        case "Brave Browser": bundleID = "com.brave.Browser"
        case "Microsoft Edge": bundleID = "com.microsoft.edgemac"
        default: return
        }
        
        // Aggressively activate the app if it's currently running
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
            app.activate(options: .activateIgnoringOtherApps)
        }
        // Fallback if it somehow isn't running
        else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: config, completionHandler: nil)
        }
    }
}
