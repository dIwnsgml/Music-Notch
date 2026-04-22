import SwiftUI
import Combine

class PluginManager: ObservableObject {
    static let shared = PluginManager()
    
    @Published var plugins: [WaveNotchPlugin] = [
        WaveNotchPlugin(
            id: "spotify_plus",
            name: "Spotify Plus",
            description: "Advanced Spotify integration with private playlist access, real-time queue synchronization, and native playback controls using official APIs.",
            iconName: "music.note",
            assetImageName: "spotify_logo",
            category: .media,
            storageKeyBase: "plugin_spotify_plus"
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
