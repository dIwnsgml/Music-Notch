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

// 🟢 NEW: Spotify Data Models
struct SpotifyPlaylistResponse: Codable {
    let items: [SpotifyPlaylist]
}

struct SpotifyPlaylist: Codable, Identifiable, Equatable {
    let id: String
    let name: String?
    let uri: String?
    let images: [SpotifyImage]?
    
    var imageURL: URL? {
        if let urlString = images?.first?.url {
            return URL(string: urlString)
        }
        return nil
    }
}

struct SpotifyImage: Codable, Equatable {
    let url: String
}

// 🟢 NEW: Spotify Queue Models
struct SpotifyQueueResponse: Codable {
    let currently_playing: SpotifyTrack?
    let queue: [SpotifyTrack]
}

struct SpotifyTrack: Codable, Identifiable, Equatable {
    var id: String { uri + (name ?? "") }
    let name: String?
    let uri: String
    let artists: [SpotifyArtist]?
    let album: SpotifyAlbum?
    
    var artistNames: String {
        artists?.map { $0.name }.joined(separator: ", ") ?? "Unknown Artist"
    }
}

struct SpotifyArtist: Codable, Equatable {
    let name: String
}

struct SpotifyAlbum: Codable, Equatable {
    let images: [SpotifyImage]?
}
