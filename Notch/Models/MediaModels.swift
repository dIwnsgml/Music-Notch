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
