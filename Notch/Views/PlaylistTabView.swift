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
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .onAppear {
            if spotifyPlaylistsEnabled {
                spotifyManager.fetchPlaylists()
            }
        }
    }
    
    private var spotifyPlaylistsContent: some View {
        VStack(alignment: .leading, spacing: 6) {
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
                    Image(systemName: "music.note.list")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.green.opacity(0.65))
                    Text("No playlists found.")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                MediaSectionHeader(
                    icon: "music.note.list",
                    title: "Spotify Playlists",
                    subtitle: "\(spotifyManager.playlists.count) saved",
                    color: .green
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(spotifyManager.playlists) { playlist in
                            SpotifyPlaylistRow(playlist: playlist) {
                                spotifyManager.playContext(uri: playlist.uri)
                            }
                        }
                    }
                }
                .frame(height: 84)
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    
    private var classicPlaylistContent: some View {
        Group {
            if nowPlaying.playlist.isEmpty {
                VStack {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(nowPlaying.artworkDominantColor.opacity(0.7))
                        .padding(.bottom, 4)
                    Text("No upcoming tracks found")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                MediaSectionHeader(
                    icon: "text.line.first.and.arrowtriangle.forward",
                    title: "Up Next",
                    subtitle: "\(nowPlaying.playlist.count) tracks",
                    color: nowPlaying.artworkDominantColor
                )
                .padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(nowPlaying.playlist) { track in
                            Button(action: {
                                nowPlaying.playTrack(track)
                            }) {
                                HStack(spacing: 10) {
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
                                    .frame(width: 38, height: 38)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    
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

                                    Spacer(minLength: 0)

                                    Image(systemName: "play.fill")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(nowPlaying.artworkDominantColor.opacity(0.82))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 7)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
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
        let artworkSize: CGFloat = 56

        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                if let urlString = playlist.imageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(Color.gray.opacity(0.2))
                    }
                    .frame(width: artworkSize, height: artworkSize)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(isHovering ? 0.35 : 0.12), radius: 8, x: 0, y: 4)
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: artworkSize, height: artworkSize)
                        .overlay(Image(systemName: "music.note.list").foregroundColor(.gray))
                }
                
                Text(playlist.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isHovering ? .green : .white)
                    .lineLimit(1)
                    .frame(width: artworkSize, alignment: .leading)
            }
            .frame(width: artworkSize, alignment: .leading)
            .padding(5)
            .background(isHovering ? Color.green.opacity(0.10) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
