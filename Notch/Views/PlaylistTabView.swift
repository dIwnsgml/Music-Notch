import SwiftUI

struct PlaylistTabView: View {
    @ObservedObject var nowPlaying: NowPlayingManager
    @StateObject private var spotifyManager = SpotifyAuthManager.shared
    
    @AppStorage("plugin_spotify_playlists_enabled") var spotifyPlaylistsEnabled = false
    
    var body: some View {
        VStack(spacing: 0) {
            if spotifyPlaylistsEnabled {
                spotifyPlaylistsContent
            } else {
                classicPlaylistContent
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .onAppear {
            if spotifyPlaylistsEnabled {
                spotifyManager.fetchPlaylists()
            }
        }
    }
    
    private var spotifyPlaylistsContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if spotifyManager.accessToken.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    let hasClientID = spotifyManager.hasValidClientID
                    
                    Image(systemName: hasClientID ? "music.note.list" : "lock.fill")
                        .font(.system(size: 20))
                        .foregroundColor(hasClientID ? .green.opacity(0.8) : .gray.opacity(0.5))
                    Text(hasClientID ? "Spotify Playlists" : "Setup Required")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(hasClientID ? .white : .gray)
                    Text(hasClientID ? "Sign in to quickly switch between your favorite playlists." : "Open Settings to set your Client ID.")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                    
                    Button(action: {
                        if hasClientID {
                            spotifyManager.authenticate { _ in }
                        } else {
                            UserDefaults.standard.set("Plugins", forKey: "lastSettingsTab")
                            SettingsWindowManager.shared.showSettings()
                        }
                    }) {
                        Text(hasClientID ? "Connect Spotify" : "Open Settings")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(hasClientID ? Color.green : Color.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if spotifyManager.playlists.isEmpty {
                VStack {
                    Spacer()
                    Text("No playlists found.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(spotifyManager.playlists) { playlist in
                            SpotifyPlaylistRow(playlist: playlist) {
                                spotifyManager.playContext(uri: playlist.uri)
                            }
                        }
                    }.padding(.vertical, 10)
                }
            }
        }
        .frame(maxWidth: .infinity)
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
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                        }
                    }
                }
            }
        }
    }
}

struct SpotifyPlaylistRow: View {
    let playlist: SpotifyPlaylist
    let action: () -> Void
    @State private var isHovering = false
    
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
                    .shadow(color: Color.black.opacity(isHovering ? 0.3 : 0.1), radius: 5, x: 0, y: 3)
                    .scaleEffect(isHovering ? 1.05 : 1.0)
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .overlay(Image(systemName: "music.note.list").foregroundColor(.gray))
                }
                
                Text(playlist.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isHovering ? .green : .white)
                    .lineLimit(1)
                    .frame(width: 80, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
    }
}
