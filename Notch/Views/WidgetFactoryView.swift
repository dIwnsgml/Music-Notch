import SwiftUI
import Combine
import EventKit

struct WidgetFactoryView: View {
    let widgetType: NotchWidgetType
    
    @ObservedObject var nowPlaying: NowPlayingManager
    @ObservedObject var calendarManager: CalendarManager
    let expandedWidth: CGFloat
    var isCompact: Bool
    @Binding var skipDirection: Int
    @Binding var glowOpacity: Double
    let onSwipe: (Bool) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            if widgetType == .spotifyPlaylists {
                Spacer(minLength: 0)
            }
            
            Group {
                switch widgetType {
                case .player:
                    PlayerTabView(
                        nowPlaying: nowPlaying,
                        calendarManager: calendarManager,
                        expandedWidth: expandedWidth,
                        isCompact: isCompact,
                        skipDirection: $skipDirection,
                        glowOpacity: $glowOpacity,
                        onSwipe: onSwipe
                    )
                case .spotifyQueue:
                    SpotifyQueueWidget(nowPlaying: nowPlaying)
                case .spotifyPlaylists:
                    PlaylistTabView(nowPlaying: nowPlaying)
                case .calendar:
                    CalendarWidget()
                case .weather:
                    PlaceholderWidget(name: "Weather", icon: "cloud.sun.fill")
                }
            }
            
            Spacer(minLength: 0)
        }
    }
}

struct CalendarWidget: View {
    @ObservedObject var googleManager = GoogleCalendarManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !googleManager.isAuthenticated {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                    Text("Google Login Required")
                        .font(.system(size: 13, weight: .bold))
                    Text("Please sign in to Google in the Plugin Store.")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if googleManager.isFetching && googleManager.upcomingEvents.isEmpty {
                VStack {
                    Spacer()
                    ProgressView().controlSize(.small)
                    Text("Syncing Google Calendar...")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .padding(.top, 4)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if googleManager.upcomingEvents.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 24))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("All clear for today!")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(googleManager.upcomingEvents) { event in
                            HStack(spacing: 10) {
                                // Calendar Color Strip
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(colorFromHex(event.calendarColor))
                                    .frame(width: 3, height: 24)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(event.summary)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    
                                    Text(formatGoogleEventTime(event))
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            googleManager.fetchTodaysEvents()
        }
    }
    
    private func colorFromHex(_ hex: String?) -> Color {
        guard let hex = hex else { return .accentColor }
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanHex.hasPrefix("#") { cleanHex.removeFirst() }
        
        var rgb: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&rgb)
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        return Color(red: r, green: g, blue: b)
    }
    
    private func formatGoogleEventTime(_ event: GoogleCalendarEvent) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        if let startStr = event.start.dateTime, let endStr = event.end.dateTime {
            let iso = ISO8601DateFormatter()
            if let start = iso.date(from: startStr), let end = iso.date(from: endStr) {
                return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
            }
        }
        
        return "All Day"
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
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(spotifyManager.currentQueueItems.prefix(50).enumerated()), id: \.offset) { index, item in
                            SpotifyQueueRow(index: index + 1, track: item.track) {
                                spotifyManager.skipToQueueItem(index: index)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            spotifyManager.fetchQueue()
        }
        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
            spotifyManager.fetchQueue()
        }
        .onChange(of: nowPlaying.currentSong) { _, _ in
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
            HStack(spacing: 10) {
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
