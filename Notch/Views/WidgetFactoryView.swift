import SwiftUI

struct WidgetFactoryView: View {
    let widgetType: NotchWidgetType
    
    // Pass along required dependencies
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
                PlaylistTabView(nowPlaying: nowPlaying)
            case .calendar:
                PlaceholderWidget(name: "Google Calendar", icon: "calendar")
            case .weather:
                PlaceholderWidget(name: "Weather", icon: "cloud.sun.fill")
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
            
            Text("\(name) Plugin")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
            
            Text("Content coming soon...")
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}
