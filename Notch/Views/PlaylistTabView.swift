import SwiftUI

struct PlaylistTabView: View {
    @ObservedObject var nowPlaying: NowPlayingManager
    @StateObject private var spotifyManager = SpotifyAuthManager.shared
    
    @AppStorage("plugin_spotify_plus_enabled") var spotifyPlusEnabled = false
    
    var body: some View {
        VStack(spacing: 0) {
            if spotifyPlusEnabled && !spotifyManager.accessToken.isEmpty {
                spotifyPlusContent
            } else {
                classicPlaylistContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if spotifyPlusEnabled {
                spotifyManager.fetchPlaylists()
                spotifyManager.fetchQueue()
            }
        }
    }
    
    private var spotifyPlusContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Spotify Plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.green)
                Spacer()
                Button(action: {
                    spotifyManager.fetchPlaylists()
                    spotifyManager.fetchQueue()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            
            if spotifyManager.playlists.isEmpty && spotifyManager.currentQueue.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "music.note.list")
                        .font(.system(size: 30))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("No data found. Make sure Spotify is open.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(spotifyManager.playlists) { playlist in
                            SpotifyPlaylistRow(playlist: playlist) {
                                spotifyManager.play(uri: playlist.uri)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 120)
                
                if !spotifyManager.currentQueue.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Up Next")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                        
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 8) {
                                ForEach(spotifyManager.currentQueue.prefix(5)) { track in
                                    SpotifyTrackRow(track: track)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }
        }
    }
    
    private var classicPlaylistContent: some View {
        Group {
            if nowPlaying.playlist.isEmpty {
                VStack {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 24))
                        .foregroundColor(.gray.opacity(0.6))
                        .padding(.bottom, 4)
                    Text("No upcoming tracks found")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(nowPlaying.playlist) { track in
                            Button(action: {
                                nowPlaying.playTrack(track)
                            }) {
                                HStack(spacing: 12) {
                                    Group {
                                        if let urlString = track.imageURL, let url = URL(string: urlString), urlString != "NO_IMAGE", !urlString.isEmpty {
                                            AsyncImage(url: url) { image in
                                                image.resizable().aspectRatio(contentMode: .fill)
                                            } placeholder: {
                                                Rectangle().fill(nowPlaying.artworkDominantColor.opacity(0.3))
                                            }
                                        } else {
                                            ZStack {
                                                Rectangle().fill(nowPlaying.artworkDominantColor.opacity(0.3))
                                                Image(systemName: "music.note")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(.white.opacity(0.8))
                                            }
                                        }
                                    }
                                    .frame(width: 32, height: 32)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        let isCurrent = nowPlaying.currentSong.contains(track.title)
                                        Text(track.title)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(isCurrent ? nowPlaying.artworkDominantColor : .white)
                                            .lineLimit(1)
                                        Text(track.artist)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(isCurrent ? nowPlaying.artworkDominantColor.opacity(0.8) : .gray)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
        }
    }
}

struct SpotifyPlaylistRow: View {
    let playlist: SpotifyPlaylist
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                if let urlString = playlist.imageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(Color.gray.opacity(0.2))
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .overlay(Image(systemName: "music.note.list").foregroundColor(.gray))
                }
                
                Text(playlist.name)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                    .frame(width: 80, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

struct SpotifyTrackRow: View {
    let track: SpotifyTrack
    
    var body: some View {
        HStack(spacing: 12) {
            if let urlString = track.album?.images?.first?.url, let url = URL(string: urlString) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color.gray.opacity(0.2))
                }
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(track.name)
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(1)
                Text(track.artists.first?.name ?? "Unknown Artist")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
    }
}
