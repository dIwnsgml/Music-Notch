import SwiftUI
import Combine
import AppKit

class NowPlayingManager: ObservableObject {
    static let shared = NowPlayingManager() // ⚡️ ADDED
    
    // ⚡️ Network Safety & Caching
    var lyricSearchTask: DispatchWorkItem? = nil
    var lyricsCache: [String: CachedLyricsEntry] = [:]
    var currentLyricsCacheKey: String? = nil
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
    @Published var artworkDominantColor: Color = .white
    @Published var isPlaying: Bool = false
    @Published var loopMode: Int = 0
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 1.0
    
    @Published var lyrics: [LyricLine] = []
    @Published var activeLyricIndex: Int = 0
    @Published var isSearchingLyrics: Bool = false
    @Published var currentSongLyricOffset: Double = 0.0
    @Published var lyricsDisabledForCurrentSong: Bool = false
    @Published var playlist: [PlaylistTrack] = []
    // ⚡️ NEW: Triggers the UI when a control is used
    @Published var lastControlAction: UUID = UUID()
    
    var timer: Timer?
    var isFetching = false
    var lastFetchTime = Date(timeIntervalSince1970: 0)
    var lastLoopToggleTime = Date(timeIntervalSince1970: 0)
    var isNotchExpandedForPolling = false
    var fastFetchWorkItem: DispatchWorkItem?
    private var currentFetchInterval: TimeInterval = 8.0
    private let nativeActiveFetchInterval: TimeInterval = 3.0
    private let browserActiveFetchInterval: TimeInterval = 1.5
    private let expandedIdleFetchInterval: TimeInterval = 3.0
    private let knownPausedFetchInterval: TimeInterval = 5.0
    private let idleFetchInterval: TimeInterval = 12.0
    private let expandedDetailedScrapeInterval: TimeInterval = 5.0
    private let collapsedFullBrowserDiscoveryInterval: TimeInterval = 60.0
    private var lastFullBrowserDiscoveryTime = Date(timeIntervalSince1970: 0)
    private var lastDetailedMediaScrapeTime = Date(timeIntervalSince1970: 0)
    private var nativePlaybackObservers: [NSObjectProtocol] = []
    
    @Published var lastActiveBrowser: String? = nil
    var lastWindowIndex: Int? = nil
    var lastTabIndex: Int? = nil

    init() {
        migrateGlobalLyricOffsetIfNeeded()
        self.lyricsCache = Self.loadLyricsCache()
        self.lastActiveBrowser = UserDefaults.standard.string(forKey: "lastActiveBrowser")
        if UserDefaults.standard.object(forKey: "lastWindowIndex") != nil {
            self.lastWindowIndex = UserDefaults.standard.integer(forKey: "lastWindowIndex")
        }
        if UserDefaults.standard.object(forKey: "lastTabIndex") != nil {
            self.lastTabIndex = UserDefaults.standard.integer(forKey: "lastTabIndex")
        }

        registerNativePlaybackObservers()
        scheduleFetchTimer(interval: currentFetchInterval)
    }

    deinit {
        nativePlaybackObservers.forEach {
            DistributedNotificationCenter.default().removeObserver($0)
        }
    }

    func setNotchExpanded(_ expanded: Bool) {
        guard isNotchExpandedForPolling != expanded else { return }
        isNotchExpandedForPolling = expanded
        scheduleFetchTimer(interval: preferredFetchInterval)

        if expanded {
            triggerFastFetch()
        }
    }

    var shouldUseDetailedMediaScrape: Bool {
        guard isNotchExpandedForPolling else { return false }
        return Date().timeIntervalSince(lastDetailedMediaScrapeTime) >= expandedDetailedScrapeInterval
    }

    func markDetailedMediaScrapeRun() {
        lastDetailedMediaScrapeTime = Date()
    }

    var shouldRunFullBrowserDiscovery: Bool {
        isNotchExpandedForPolling || Date().timeIntervalSince(lastFullBrowserDiscoveryTime) >= collapsedFullBrowserDiscoveryInterval
    }

    func markFullBrowserDiscoveryRun() {
        lastFullBrowserDiscoveryTime = Date()
    }

    private var preferredFetchInterval: TimeInterval {
        if isPlaying {
            return isLastActiveNativePlayer ? nativeActiveFetchInterval : browserActiveFetchInterval
        }
        if lastActiveBrowser != nil {
            return isLastActiveNativePlayer ? knownPausedFetchInterval : expandedIdleFetchInterval
        }
        if isNotchExpandedForPolling {
            return expandedIdleFetchInterval
        }
        return idleFetchInterval
    }

    private var isLastActiveNativePlayer: Bool {
        lastActiveBrowser == "SpotifyNative" || lastActiveBrowser == "AppleMusicNative"
    }

    func refreshFetchTimerIfNeeded() {
        let interval = preferredFetchInterval
        guard abs(interval - currentFetchInterval) > 0.01 else { return }
        scheduleFetchTimer(interval: interval)
    }

    private func scheduleFetchTimer(interval: TimeInterval) {
        timer?.invalidate()
        currentFetchInterval = interval

        let newTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.fetchTitle()
        }
        newTimer.tolerance = interval < 2 ? 0.08 : max(0.75, interval * 0.25)
        timer = newTimer
        RunLoop.main.add(newTimer, forMode: .common)
    }

    private func registerNativePlaybackObservers() {
        let center = DistributedNotificationCenter.default()
        let names = [
            "com.spotify.client.PlaybackStateChanged",
            "com.apple.iTunes.playerInfo",
            "com.apple.Music.playerInfo"
        ]

        nativePlaybackObservers = names.map { name in
            center.addObserver(
                forName: Notification.Name(name),
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.handleNativePlaybackNotification(notification)
            }
        }
    }

    private func handleNativePlaybackNotification(_ notification: Notification) {
        let notificationName = notification.name.rawValue
        if notificationName.contains("spotify"), !enableSpotify { return }
        if notificationName.contains("Music") || notificationName.contains("iTunes"), !enableAppleMusic { return }

        let state = (notification.userInfo?["Player State"] as? String ?? "").lowercased()
        if state.contains("playing") {
            if !isPlaying { isPlaying = true }
        } else if state.contains("paused") || state.contains("stopped") {
            if isPlaying { isPlaying = false }
        }

        let appliedRichState = applyNativePlaybackNotification(
            notificationName: notificationName,
            userInfo: notification.userInfo ?? [:],
            playbackState: state
        )

        refreshFetchTimerIfNeeded()
        if !appliedRichState {
            triggerFastFetch()
        }
    }

    @discardableResult
    private func applyNativePlaybackNotification(
        notificationName: String,
        userInfo: [AnyHashable: Any],
        playbackState: String
    ) -> Bool {
        let isSpotify = notificationName.contains("spotify")
        let browser = isSpotify ? "SpotifyNative" : "AppleMusicNative"

        guard let title = firstString(in: userInfo, keys: ["Name", "Title"]),
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        let artist = firstString(in: userInfo, keys: ["Artist", "Album Artist"]) ?? ""
        let displayString = artist.isEmpty ? title : "\(title) - \(artist)"
        let identifier = title + artist

        let rawDuration = firstDouble(in: userInfo, keys: ["Duration", "Total Time", "TotalTime"]) ?? duration
        let nextDuration = rawDuration > 10_000 ? rawDuration / 1000.0 : rawDuration
        let nextTime = firstDouble(in: userInfo, keys: ["Playback Position", "Player Position", "Position"]) ?? currentTime

        if lastActiveBrowser != browser {
            lastActiveBrowser = browser
            UserDefaults.standard.set(browser, forKey: "lastActiveBrowser")
        }
        if lastWindowIndex != nil {
            lastWindowIndex = nil
            UserDefaults.standard.removeObject(forKey: "lastWindowIndex")
        }
        if lastTabIndex != nil {
            lastTabIndex = nil
            UserDefaults.standard.removeObject(forKey: "lastTabIndex")
        }

        if abs(duration - nextDuration) > 0.25 {
            duration = max(nextDuration, 1)
        }

        if internalSongIdentifier != identifier {
            internalSongIdentifier = identifier
            if currentTime != 0 { currentTime = 0 }
            fetchLyricsEngine(title: title, artist: artist)

            if isSpotify,
               let artworkString = firstString(in: userInfo, keys: ["Artwork URL", "ArtworkURL", "Album Artwork URL"]),
               let url = URL(string: artworkString),
               artworkURL != url {
                artworkURL = url
                fetchDominantColor(from: url)
            } else if isSpotify {
                fetchSpotifyNativeArtwork(expectedIdentifier: identifier)
            } else if !isSpotify {
                fetchAppleMusicArtwork(title: title, artist: artist)
            }
        }

        if currentSong != displayString {
            currentSong = displayString
        }
        if abs(currentTime - nextTime) > 1.5 {
            currentTime = max(nextTime, 0)
        }
        if playbackState.contains("playing"), !isPlaying {
            isPlaying = true
        } else if (playbackState.contains("paused") || playbackState.contains("stopped")), isPlaying {
            isPlaying = false
        }

        return true
    }

    private func firstString(in userInfo: [AnyHashable: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = userInfo[key] as? String, !value.isEmpty {
                return value
            }
            if let value = userInfo[key] as? NSString, value.length > 0 {
                return value as String
            }
        }
        return nil
    }

    private func firstDouble(in userInfo: [AnyHashable: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = userInfo[key] as? Double { return value }
            if let value = userInfo[key] as? Int { return Double(value) }
            if let value = userInfo[key] as? NSNumber { return value.doubleValue }
            if let value = userInfo[key] as? String, let parsed = Double(value) { return parsed }
        }
        return nil
    }

    private func fetchSpotifyNativeArtwork(expectedIdentifier: String) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let script = """
            tell application "Spotify"
                if player state is stopped then return "NO_IMAGE"
                try
                    return artwork url of current track
                on error
                    return "NO_IMAGE"
                end try
            end tell
            """

            guard let artworkString = NSAppleScript(source: script)?.executeAndReturnError(nil).stringValue,
                  artworkString != "NO_IMAGE",
                  let url = URL(string: artworkString) else {
                return
            }

            DispatchQueue.main.async {
                guard let self, self.internalSongIdentifier == expectedIdentifier else { return }
                guard self.artworkURL != url else { return }
                self.artworkURL = url
                self.fetchDominantColor(from: url)
            }
        }
    }
    
    // ---------------------------------------------------------
    // ⚡️ THE FIX: Smart App Activation based on PLAYING STATE
    // ---------------------------------------------------------
    func openPlayingApp() {
        // Run this on a background thread so the AppleScript check doesn't freeze the UI!
        DispatchQueue.global(qos: .userInitiated).async {
            let runningApps = NSWorkspace.shared.runningApplications
            
            // 1. Check if Spotify is explicitly PLAYING
            let spotifyBundle = "com.spotify.client"
            if runningApps.contains(where: { $0.bundleIdentifier == spotifyBundle }) {
                if self.checkNativePlayerState(appName: "Spotify") == "playing" {
                    DispatchQueue.main.async { self.activateApp(bundleID: spotifyBundle) }
                    return
                }
            }
            
            // 2. Check if Apple Music is explicitly PLAYING
            let musicBundle = "com.apple.Music"
            if runningApps.contains(where: { $0.bundleIdentifier == musicBundle }) {
                if self.checkNativePlayerState(appName: "Music") == "playing" {
                    DispatchQueue.main.async { self.activateApp(bundleID: musicBundle) }
                    return
                }
            }
            
            // 3. If neither native app is playing, fall back to the active browser!
            if let browser = self.lastActiveBrowser {
                DispatchQueue.main.async { self.activateApp(appName: browser) }
                return
            }
            
            // 4. Absolute Fallback: If everything is paused, open whichever native app is running
            if runningApps.contains(where: { $0.bundleIdentifier == spotifyBundle }) {
                DispatchQueue.main.async { self.activateApp(bundleID: spotifyBundle) }
            } else if runningApps.contains(where: { $0.bundleIdentifier == musicBundle }) {
                DispatchQueue.main.async { self.activateApp(bundleID: musicBundle) }
            }
        }
    }
    
    // Asks the native app for its exact playback state ("playing", "paused", or "stopped")
    private func checkNativePlayerState(appName: String) -> String {
        let script = "tell application \"\(appName)\" to get player state as string"
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            return appleScript.executeAndReturnError(&error).stringValue?.lowercased() ?? "stopped"
        }
        return "stopped"
    }
    
    // Updated to accept either an appName (for browsers) or a direct bundleID
    private func activateApp(appName: String? = nil, bundleID: String? = nil) {
        var targetBundleID = bundleID
        
        if let appName = appName {
            switch appName {
            case "Safari": targetBundleID = "com.apple.Safari"
            case "Google Chrome": targetBundleID = "com.google.Chrome"
            case "Brave Browser": targetBundleID = "com.brave.Browser"
            case "Microsoft Edge": targetBundleID = "com.microsoft.edgemac"
            default: break
            }
        }
        
        guard let finalBundleID = targetBundleID else { return }
        
        // Aggressively activate the app if it's currently running
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == finalBundleID }) {
            app.activate(options: .activateIgnoringOtherApps)
        }
        // Fallback if it somehow isn't running
        else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: finalBundleID) {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: config, completionHandler: nil)
        }
    }
}
