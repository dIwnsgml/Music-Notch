import SwiftUI
import Combine

struct WidgetFactoryView: View {
    let widgetType: NotchWidgetType
    
    @ObservedObject var nowPlaying: NowPlayingManager
    @ObservedObject var calendarManager: CalendarManager
    let expandedWidth: CGFloat
    var isCompact: Bool // ⚡️ ADDED
    @Binding var skipDirection: Int
    @Binding var glowOpacity: Double
    let onSwipe: (Bool) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch widgetType {
                case .player:
                    PlayerTabView(
                        nowPlaying: nowPlaying,
                        calendarManager: calendarManager,
                        expandedWidth: expandedWidth,
                        isCompact: isCompact, // ⚡️ ADDED
                        skipDirection: $skipDirection,
                        glowOpacity: $glowOpacity,
                        onSwipe: onSwipe
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
            Spacer(minLength: 0)
        }
    }
}

struct SpotifyQueueWidget: View {
    @ObservedObject var nowPlaying: NowPlayingManager
    @StateObject private var spotifyManager = SpotifyAuthManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if spotifyManager.accessToken.isEmpty {
                emptyStateView(text: "Please enable Spotify Plus in Settings.")
            } else if spotifyManager.currentQueueItems.isEmpty {
                emptyStateView(text: "Fetching queue...")
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(spotifyManager.currentQueueItems.prefix(50).enumerated()), id: \.offset) { index, item in
                            SpotifyQueueRow(index: index + 1, track: item.track) {
                                spotifyManager.skipToQueueItem(index: index)
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            spotifyManager.fetchQueue()
        }
        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
            // ⚡️ PERIODIC REFRESH: Keep the queue synced every 5 seconds while expanded
            spotifyManager.fetchQueue()
        }
        .onChange(of: nowPlaying.currentSong) { _, _ in
            // ⚡️ INSTANT REFRESH: When the track changes, grab the new queue immediately
            spotifyManager.fetchQueue()
        }
    }
    
    private func emptyStateView(text: String) -> some View {
        VStack {
            Spacer()
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct SpotifyQueueRow: View {
    let index: Int
    let track: SpotifyTrack
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text("\(index)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(isHovering ? .green : .gray)
                    .frame(width: 18, alignment: .trailing)
                
                if let urlString = track.album?.images?.first?.url, let url = URL(string: urlString) {
                    AsyncImage(url: url) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle().fill(Color.gray.opacity(0.2))
                    }
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    if isHovering {
                        MarqueeText(text: track.name, font: .system(size: 12, weight: .bold), alignment: .leading)
                            .foregroundColor(.green)
                            .frame(height: 14)
                    } else {
                        Text(track.name)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .frame(height: 14, alignment: .leading)
                    }
                    Text(track.artists.first?.name ?? "Unknown Artist")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isHovering {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
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
