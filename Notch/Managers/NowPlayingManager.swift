import SwiftUI
import Combine
import AppKit

class NowPlayingManager: ObservableObject {
    @Published var currentSong: String = "No Music"
    var internalSongIdentifier: String = ""
    
    // ⚡️ NEW: Opt-in toggles linked to macOS User Defaults
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
}
