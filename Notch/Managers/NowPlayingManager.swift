import SwiftUI
import Combine
import AppKit

class NowPlayingManager: ObservableObject {
    @Published var currentSong: String = "No Music"
    var internalSongIdentifier: String = ""
    
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
    
    var timer: Timer?
    var isFetching = false
    var lastFetchTime = Date(timeIntervalSince1970: 0)
    var lastLoopToggleTime = Date(timeIntervalSince1970: 0)
    
    var lastActiveBrowser: String? = nil
    var lastWindowIndex: Int? = nil
    var lastTabIndex: Int? = nil
    
    let supportedBrowsers = ["Google Chrome", "Brave Browser", "Microsoft Edge", "Safari"]
    
    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.fetchTitle()
        }
    }
}
