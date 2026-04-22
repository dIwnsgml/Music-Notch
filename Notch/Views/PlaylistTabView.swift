import SwiftUI

struct PlaylistTabView: View {
    @ObservedObject var nowPlaying: NowPlayingManager
    @StateObject private var spotifyManager = SpotifyAuthManager.shared
    
    @AppStorage("plugin_spotify_playlists_enabled") var spotifyPlaylistsEnabled = false
    
    var body: some View {
        VStack(spacing: 0) {
            if spotifyPlaylistsEnabled && !spotifyManager.accessToken.isEmpty {
                spotifyPlaylistsContent
            } else {
                classicPlaylistContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if spotifyPlaylistsEnabled {
                spotifyManager.fetchPlaylists()
            }
        }
    }
    
    private var spotifyPlaylistsContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Spotify Playlists")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.green)
                Spacer()
            }
            .padding(.horizontal, 16)
            
            if spotifyManager.playlists.isEmpty {
                VStack {
                    Spacer()
                    Text("No playlists found.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(spotifyManager.playlists) { playlist in
                            Button(action: {
                                spotifyManager.play(uri: playlist.uri)
                            }) {
                                HStack(spacing: 12) {
                                    if let urlString = playlist.imageUrl, let url = URL(string: urlString) {
                                        AsyncImage(url: url) { image in
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Rectangle().fill(Color.gray.opacity(0.2))
                                        }
                                        .frame(width: 32, height: 32)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    }
                                    
                                    Text(playlist.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
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
