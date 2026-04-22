import SwiftUI
import Combine

enum NotchWidgetType: String, Codable, CaseIterable, Identifiable {
    case nowPlaying
    case playlist
    case calendar
    case weather
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .nowPlaying: return "Now Playing"
        case .playlist: return "Playlists & Queue"
        case .calendar: return "Calendar"
        case .weather: return "Weather"
        }
    }
}

class DashboardManager: ObservableObject {
    static let shared = DashboardManager()
    
    @Published var activeLayout: [NotchWidgetType] = [] {
        didSet {
            saveLayout()
        }
    }
    
    @AppStorage("enableSpotifyPlus_enabled") private var enableSpotifyPlus: Bool = false
    @AppStorage("enableCalendar_enabled") private var enableCalendar: Bool = false
    @AppStorage("enableWeather_enabled") private var enableWeather: Bool = false
    
    init() {
        loadLayout()
        refreshAvailableWidgets()
    }
    
    private func saveLayout() {
        if let data = try? JSONEncoder().encode(activeLayout) {
            UserDefaults.standard.set(data, forKey: "dashboardActiveLayout")
        }
    }
    
    private func loadLayout() {
        if let data = UserDefaults.standard.data(forKey: "dashboardActiveLayout"),
           let savedLayout = try? JSONDecoder().decode([NotchWidgetType].self, from: data) {
            activeLayout = savedLayout
        } else {
            activeLayout = [.nowPlaying]
        }
    }
    
    func refreshAvailableWidgets() {
        var newLayout = activeLayout
        var didChange = false
        
        if !newLayout.contains(.nowPlaying) {
            newLayout.insert(.nowPlaying, at: 0)
            didChange = true
        }
        
        if enableSpotifyPlus {
            if !newLayout.contains(.playlist) {
                newLayout.append(.playlist)
                didChange = true
            }
        } else {
            if newLayout.contains(.playlist) {
                newLayout.removeAll { $0 == .playlist }
                didChange = true
            }
        }
        
        if enableCalendar {
            if !newLayout.contains(.calendar) {
                newLayout.append(.calendar)
                didChange = true
            }
        } else {
            if newLayout.contains(.calendar) {
                newLayout.removeAll { $0 == .calendar }
                didChange = true
            }
        }
        
        if enableWeather {
            if !newLayout.contains(.weather) {
                newLayout.append(.weather)
                didChange = true
            }
        } else {
            if newLayout.contains(.weather) {
                newLayout.removeAll { $0 == .weather }
                didChange = true
            }
        }
        
        if didChange {
            activeLayout = newLayout
        }
    }
}
