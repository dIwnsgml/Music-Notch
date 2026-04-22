import Foundation

struct LRCTrack: Codable {
    let trackName: String?
    let artistName: String?
    let syncedLyrics: String?
}

struct LyricLine: Equatable {
    let time: Double
    let text: String
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
