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
    
    func getWidgetOrder() -> [NotchWidgetType] {
        if let data = UserDefaults.standard.data(forKey: "dashboard_widget_order"),
           let savedOrder = try? JSONDecoder().decode([NotchWidgetType].self, from: data) {
            
            // Ensure all enum cases are accounted for (e.g., if new plugins were added in an update)
            var fullOrder = savedOrder
            let missing = NotchWidgetType.allCases.filter { !fullOrder.contains($0) }
            fullOrder.append(contentsOf: missing)
            return fullOrder
        }
        return NotchWidgetType.allCases
    }
    
    func saveWidgetOrder(_ order: [NotchWidgetType]) {
        if let data = try? JSONEncoder().encode(order) {
            UserDefaults.standard.set(data, forKey: "dashboard_widget_order")
        }
        refreshWidgets() // Live sync the notch!
    }
    
    func refreshWidgets() {
        let playerEnabled = UserDefaults.standard.object(forKey: "plugin_player_enabled") as? Bool ?? true
        let queueEnabled = UserDefaults.standard.bool(forKey: "plugin_spotify_queue_enabled")
        let playlistsEnabled = UserDefaults.standard.bool(forKey: "plugin_spotify_playlists_enabled")
        let calendarEnabled = UserDefaults.standard.bool(forKey: "plugin_google_calendar_enabled")
        let weatherEnabled = UserDefaults.standard.bool(forKey: "plugin_weather_enabled")
        
        let order = getWidgetOrder()
        var widgets: [NotchWidgetType] = []
        
        for widget in order {
            switch widget {
            case .player: if playerEnabled { widgets.append(.player) }
            case .spotifyQueue: if queueEnabled { widgets.append(.spotifyQueue) }
            case .spotifyPlaylists: if playlistsEnabled { widgets.append(.spotifyPlaylists) }
            case .calendar: if calendarEnabled { widgets.append(.calendar) }
            case .weather: if weatherEnabled { widgets.append(.weather) }
            }
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
