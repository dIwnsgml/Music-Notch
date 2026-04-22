import SwiftUI

struct WidgetFactoryView: View {
    let type: NotchWidgetType
    
    @ObservedObject var nowPlaying: NowPlayingManager
    @ObservedObject var calendarManager: CalendarManager
    let expandedWidth: CGFloat
    @Binding var skipDirection: Int
    @Binding var glowOpacity: Double
    let onSwipe: (Bool) -> Void
    
    var body: some View {
        switch type {
        case .nowPlaying:
            // Calculate width based on whether it's full width or half width
            let activeCount = DashboardManager.shared.activeLayout.filter { type in
                if type == .playlist {
                    let isSpotifyActive = nowPlaying.lastActiveBrowser == "SpotifyNative" || (nowPlaying.lastActiveBrowser?.contains("Spotify") ?? false)
                    return isSpotifyActive
                }
                return true
            }.count
            
            let columnWidth = (activeCount <= 1) ? expandedWidth : (expandedWidth / 2) - 8
            
            PlayerTabView(
                nowPlaying: nowPlaying, 
                calendarManager: calendarManager, 
                expandedWidth: columnWidth, 
                skipDirection: $skipDirection, 
                glowOpacity: $glowOpacity,
                onSwipe: onSwipe
            )
            .frame(maxWidth: .infinity, alignment: .top)
        case .playlist:
            let isSpotifyActive = nowPlaying.lastActiveBrowser == "SpotifyNative" || (nowPlaying.lastActiveBrowser?.contains("Spotify") ?? false)
            if isSpotifyActive {
                PlaylistTabView(nowPlaying: nowPlaying)
                    .frame(height: 250)
                    .clipped() // ⚡️ THE FIX: Prevents overflow into other areas
            }
        case .calendar:
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
                Text("Calendar Widget")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
            .frame(height: 100)
        case .weather:
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
                Text("Weather Widget")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
            .frame(height: 100)
        }
    }
}

struct ExpandedDashboardView: View {
    @ObservedObject private var dashboardManager = DashboardManager.shared
    
    @ObservedObject var nowPlaying: NowPlayingManager
    @ObservedObject var calendarManager: CalendarManager
    let expandedWidth: CGFloat
    @Binding var skipDirection: Int
    @Binding var glowOpacity: Double
    let onSwipe: (Bool) -> Void
    
    var body: some View {
        let activeWidgets = dashboardManager.activeLayout.filter { type in
            if type == .playlist {
                let isSpotifyActive = nowPlaying.lastActiveBrowser == "SpotifyNative" || (nowPlaying.lastActiveBrowser?.contains("Spotify") ?? false)
                return isSpotifyActive
            }
            return true
        }
        
        let columns = activeWidgets.count > 1 ? [
            GridItem(.flexible(), spacing: 16, alignment: .top), // ⚡️ TOP ALIGNED
            GridItem(.flexible(), spacing: 16, alignment: .top)  // ⚡️ TOP ALIGNED
        ] : [
            GridItem(.flexible(), alignment: .top)
        ]
        
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(activeWidgets) { widget in
                WidgetFactoryView(
                    type: widget,
                    nowPlaying: nowPlaying,
                    calendarManager: calendarManager,
                    expandedWidth: expandedWidth,
                    skipDirection: $skipDirection,
                    glowOpacity: $glowOpacity,
                    onSwipe: onSwipe
                )
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .onAppear {
            dashboardManager.refreshAvailableWidgets()
        }
    }
}