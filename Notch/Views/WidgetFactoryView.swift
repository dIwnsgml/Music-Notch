import SwiftUI

struct WidgetFactoryView: View {
    let widgetType: NotchWidgetType
    
    @ObservedObject var nowPlaying: NowPlayingManager
    @ObservedObject var calendarManager: CalendarManager
    let expandedWidth: CGFloat
    @Binding var skipDirection: Int
    @Binding var glowOpacity: Double
    
    var body: some View {
        Group {
            switch widgetType {
            case .player:
                PlayerTabView(
                    nowPlaying: nowPlaying,
                    calendarManager: calendarManager,
                    expandedWidth: expandedWidth,
                    skipDirection: $skipDirection,
                    glowOpacity: $glowOpacity
                )
            case .spotifyQueue:
                SpotifyQueueWidget(nowPlaying: nowPlaying)
            case .spotifyPlaylists:
                PlaylistTabView(nowPlaying: nowPlaying)
            case .calendar:
                PlaceholderWidget(name: "Calendar", icon: "calendar")
            case .weather:
                PlaceholderWidget(name: "Weather", icon: "cloud.sun.fill")
            }
        }
    }
}

struct SpotifyQueueWidget: View {
    @ObservedObject var nowPlaying: NowPlayingManager
    @StateObject private var spotifyManager = SpotifyAuthManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Spotify Queue")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.green)
                Spacer()
            }
            .padding(.horizontal, 16)
            
            if spotifyManager.accessToken.isEmpty {
                VStack {
                    Spacer()
                    Text("Please enable Spotify Plus in Settings.")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if spotifyManager.currentQueue.isEmpty {
                VStack {
                    Spacer()
                    Text("No queue data found.")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(spotifyManager.currentQueue.prefix(5)) { track in
                            HStack(spacing: 8) {
                                if let urlString = track.album?.images?.first?.url, let url = URL(string: urlString) {
                                    AsyncImage(url: url) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Rectangle().fill(Color.gray.opacity(0.2))
                                    }
                                    .frame(width: 24, height: 24)
                                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                                }
                                
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(track.name)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    Text(track.artists.first?.name ?? "")
                                        .font(.system(size: 9))
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .onAppear {
            spotifyManager.fetchQueue()
        }
    }
}

struct PlaceholderWidget: View {
    let name: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.accentColor)
            
            Text("\(name)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}
