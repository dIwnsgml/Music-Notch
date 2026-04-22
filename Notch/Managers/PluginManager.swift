import SwiftUI
import Combine

class PluginManager: ObservableObject {
    static let shared = PluginManager()
    
    @Published var plugins: [WaveNotchPlugin] = [
        WaveNotchPlugin(
            id: "spotify_queue",
            name: "Spotify Queue",
            description: "View and manage your real-time Spotify play queue directly in the notch.",
            iconName: "list.bullet.indent",
            assetImageName: "spotify_logo",
            category: .media,
            storageKeyBase: "plugin_spotify_queue"
        ),
        WaveNotchPlugin(
            id: "spotify_playlists",
            name: "Spotify Playlists",
            description: "Quickly access and switch between your favorite Spotify playlists with one tap.",
            iconName: "music.note.list",
            assetImageName: "spotify_logo",
            category: .media,
            storageKeyBase: "plugin_spotify_playlists"
        ),
        WaveNotchPlugin(
            id: "google_calendar",
            name: "Google Calendar",
            description: "View your upcoming events and schedule directly in the notch. Supports multiple calendars and provides timely meeting alerts.",
            iconName: "calendar",
            assetImageName: "calendar_logo",
            category: .productivity,
            storageKeyBase: "plugin_google_calendar"
        ),
        WaveNotchPlugin(
            id: "weather",
            name: "Weather",
            description: "Real-time local weather conditions, temperature, and precipitation forecasts displayed beautifully in your Dynamic Island.",
            iconName: "cloud.sun.fill",
            assetImageName: "weather_logo",
            category: .system,
            storageKeyBase: "plugin_weather"
        )
    ]
}
