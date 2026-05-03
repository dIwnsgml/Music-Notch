import Foundation

nonisolated struct LRCTrack: Codable {
    let id: Int?
    let trackName: String?
    let artistName: String?
    let albumName: String?
    let duration: Double?
    let plainLyrics: String?
    let syncedLyrics: String?
}

nonisolated struct LyricLine: Codable, Equatable, Sendable {
    let time: Double
    let text: String
}

nonisolated struct CachedLyricsEntry: Codable, Equatable, Sendable {
    var lyrics: [LyricLine]
    var songOffset: Double
    var noLyrics: Bool
    var updatedAt: Date
}

nonisolated struct LyricsSearchQuery: Equatable, Sendable {
    var title: String
    var artist: String
}

nonisolated enum LyricsSearchSource: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case cache = "Cached"
    case lrclib = "LRCLIB"
    case lyricsOVH = "Lyrics.ovh"
    case netease = "Netease"

    var id: String { rawValue }
}

nonisolated struct LyricsSearchResult: Identifiable, Equatable, Sendable {
    let id: UUID
    let source: LyricsSearchSource
    let title: String
    let artist: String
    let album: String?
    let lyricsText: String
    let lines: [LyricLine]
    let isSynced: Bool
    let score: Double

    init(
        id: UUID = UUID(),
        source: LyricsSearchSource,
        title: String,
        artist: String,
        album: String? = nil,
        lyricsText: String,
        lines: [LyricLine],
        isSynced: Bool,
        score: Double
    ) {
        self.id = id
        self.source = source
        self.title = title
        self.artist = artist
        self.album = album
        self.lyricsText = lyricsText
        self.lines = lines
        self.isSynced = isSynced
        self.score = score
    }
}

struct PlaylistTrack: Identifiable, Equatable {
    var id: String { title + artist }
    let title: String
    let artist: String
    let imageURL: String?
}

// MARK: - Spotify Models

struct SpotifyPlaylist: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let images: [SpotifyImage]?
    let uri: String
    
    var imageUrl: String? {
        images?.first?.url
    }
}

struct SpotifyPlaylistResponse: Codable {
    let items: [SpotifyPlaylist]
}

struct SpotifyImage: Codable, Equatable {
    let url: String
    let height: Int?
    let width: Int?
}

struct SpotifyQueue: Codable {
    let currently_playing: SpotifyTrack?
    let queue: [SpotifyTrack]
}

struct SpotifyTrack: Codable, Identifiable, Equatable {
    var id: String { uri }
    let name: String
    let uri: String
    let artists: [SpotifyArtist]
    let album: SpotifyAlbum?
    
    struct SpotifyArtist: Codable, Equatable {
        let name: String
    }
    
    struct SpotifyAlbum: Codable, Equatable {
        let images: [SpotifyImage]?
    }
}

struct SpotifyQueueItem: Identifiable, Equatable {
    let id: String // Unique ID (index + uri)
    let track: SpotifyTrack
}

// MARK: - Google Calendar Models

struct GoogleCalendarListResponse: Codable {
    let items: [GoogleCalendar]
}

struct GoogleCalendar: Codable, Identifiable {
    let id: String
    let summary: String
    let backgroundColor: String?
}

struct GoogleCalendarEventsResponse: Codable {
    let items: [GoogleCalendarEvent]
}

struct GoogleCalendarEvent: Codable, Identifiable {
    let id: String
    let summary: String
    let description: String?
    let start: GoogleCalendarTime
    let end: GoogleCalendarTime
    let htmlLink: String?
    let calendarId: String? // Custom field to track source
    let calendarColor: String? // Custom field to track color
}

struct GoogleCalendarTime: Codable {
    let dateTime: String?
    let date: String? // For all-day events
}

// MARK: - YouTube Music Models

struct YTPlaylistResponse: Codable {
    let items: [YTPlaylist]
}

struct YTPlaylist: Codable, Identifiable {
    let id: String
    let snippet: YTSnippet
    
    struct YTSnippet: Codable {
        let title: String
        let thumbnails: YTThumbnails?
    }
}

struct YTPlaylistItemsResponse: Codable {
    let items: [YTTrack]
}

struct YTTrack: Codable, Identifiable {
    let id: String
    let snippet: YTSnippet
    
    struct YTSnippet: Codable {
        let title: String
        let videoOwnerChannelTitle: String? // Artist name
        let thumbnails: YTThumbnails?
        let resourceId: YTResourceId
    }
    
    struct YTResourceId: Codable {
        let videoId: String
    }
}

struct YTThumbnails: Codable {
    let `default`: YTThumbnail?
    let medium: YTThumbnails.YTThumbnail?
    let high: YTThumbnails.YTThumbnail?
    
    struct YTThumbnail: Codable {
        let url: String
    }
}

struct YTQueueItem: Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let imageURL: String?
    let videoId: String
    let playlistId: String? // ⚡️ NEW: To keep playback context
    
    static func == (lhs: YTQueueItem, rhs: YTQueueItem) -> Bool {
        lhs.id == rhs.id
    }
}
