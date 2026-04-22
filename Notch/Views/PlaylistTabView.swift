import SwiftUI

struct PlaylistTabView: View {
    @ObservedObject var nowPlaying: NowPlayingManager
    @ObservedObject private var spotifyManager = SpotifyAuthManager.shared
    
    @AppStorage("enableSpotifyPlus_enabled") private var enableSpotifyPlus: Bool = false
    @AppStorage("spotifyAccessToken") private var spotifyAccessToken: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            let isSpotifyActive = nowPlaying.lastActiveBrowser == "SpotifyNative" || (nowPlaying.lastActiveBrowser?.contains("Spotify") ?? false)
            
            if enableSpotifyPlus && !spotifyAccessToken.isEmpty && isSpotifyActive {
                if spotifyManager.spotifyQueue.isEmpty {
                    VStack {
                        ProgressView().controlSize(.small)
                            .padding(.bottom, 8)
                        Text("Loading Queue...")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Current Queue")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.accentColor)
                            
                            Spacer()
                            
                            Text("Spotify")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.gray.opacity(0.8))
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(spotifyManager.spotifyQueue) { track in
                                    SpotifyQueueRow(track: track) {
                                        spotifyManager.playSpotifyTrack(uri: track.uri)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                        }
                    }
                }
            } else {
                Color.clear.frame(height: 1)
            }
        }
        .onAppear {
            if enableSpotifyPlus && !spotifyAccessToken.isEmpty {
                spotifyManager.fetchSpotifyQueue()
            }
        }
    }
}

struct SpotifyQueueRow: View {
    let track: SpotifyTrack
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let urlString = track.album?.images?.first?.url, let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                } else {
                    ZStack {
                        Rectangle().fill(Color.gray.opacity(0.3))
                        Image(systemName: "music.note")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.name ?? "Unknown Track")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isHovering ? .accentColor : .white)
                        .lineLimit(1)
                    Text(track.artistNames)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                Spacer()
                
                if isHovering {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}