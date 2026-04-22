import SwiftUI
import Combine

enum NotchWidgetType: String, Codable, CaseIterable, Identifiable {
    case player
    case spotifyQueue
    case calendar
    case weather
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .player: return "Music Player"
        case .spotifyQueue: return "Spotify Queue"
        case .calendar: return "Calendar"
        case .weather: return "Weather"
        }
    }
}

class DashboardManager: ObservableObject {
    static let shared = DashboardManager()
    
    // We always have the player by default
    @Published var activeWidgets: [NotchWidgetType] = [.player]
    
    @AppStorage("plugin_spotify_plus_enabled") private var spotifyEnabled = false
    @AppStorage("plugin_google_calendar_enabled") private var calendarEnabled = false
    @AppStorage("plugin_weather_enabled") private var weatherEnabled = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Watch for plugin toggles to refresh the dashboard
        // In a real Obsidian-style app, this would be more dynamic, 
        // but for Core Plugins, we map toggles to WidgetTypes.
        
        refreshWidgets()
    }
    
    func refreshWidgets() {
        var widgets: [NotchWidgetType] = [.player]
        
        if spotifyEnabled {
            widgets.append(.spotifyQueue)
        }
        
        if calendarEnabled {
            widgets.append(.calendar)
        }
        
        if weatherEnabled {
            widgets.append(.weather)
        }
        
        // Ensure the order or presence is updated
        DispatchQueue.main.async {
            self.activeWidgets = widgets
        }
    }
}
