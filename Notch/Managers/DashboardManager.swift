import SwiftUI
import Combine

enum NotchWidgetType: String, Codable, CaseIterable, Identifiable {
    case player
    case spotifyQueue
    case spotifyPlaylists
    case calendar
    case weather
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .player: return "Music Player"
        case .spotifyQueue: return "Spotify Queue"
        case .spotifyPlaylists: return "Spotify Playlists"
        case .calendar: return "Calendar"
        case .weather: return "Weather"
        }
    }
}

class DashboardManager: ObservableObject {
    static let shared = DashboardManager()
    
    @Published var activeWidgets: [NotchWidgetType] = [.player]
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Observe key AppStorage changes to trigger live refresh
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .milliseconds(100), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshWidgets()
            }
            .store(in: &cancellables)
        
        refreshWidgets()
    }
    
    func refreshWidgets() {
        let queueEnabled = UserDefaults.standard.bool(forKey: "plugin_spotify_queue_enabled")
        let playlistsEnabled = UserDefaults.standard.bool(forKey: "plugin_spotify_playlists_enabled")
        let calendarEnabled = UserDefaults.standard.bool(forKey: "plugin_google_calendar_enabled")
        let weatherEnabled = UserDefaults.standard.bool(forKey: "plugin_weather_enabled")
        
        var widgets: [NotchWidgetType] = [.player]
        
        if queueEnabled {
            widgets.append(.spotifyQueue)
        }
        
        if playlistsEnabled {
            widgets.append(.spotifyPlaylists)
        }
        
        if calendarEnabled {
            widgets.append(.calendar)
        }
        
        if weatherEnabled {
            widgets.append(.weather)
        }
        
        DispatchQueue.main.async {
            if self.activeWidgets != widgets {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    self.activeWidgets = widgets
                    // Notify window centering logic
                    NotificationCenter.default.post(name: NSNotification.Name("UpdateNotchLayout"), object: nil)
                }
            }
        }
    }
}
