import SwiftUI
import Combine

class PluginManager: ObservableObject {
    static let shared = PluginManager()
    
    @Published var availablePlugins: [WaveNotchPlugin] = [
        // 🎵 MEDIA
        WaveNotchPlugin(id: "spotify_plus", name: "Spotify Plus", description: "Premium OAuth 2.0 integration. Read private playlists and control playback using the official Spotify API.", assetImageName: "spotify_plus_logo", category: .media, isPremium: true, storageKey: "enableSpotifyPlus"),
        WaveNotchPlugin(id: "applemusic", name: "Apple Music", description: "Deep macOS integration. View your active queue, skip tracks, and read live lyrics without ever switching windows.", assetImageName: "apple_music_logo", category: .media, isPremium: false, storageKey: "enableAppleMusic"),
        
        // 🛠 PRODUCTIVITY
        WaveNotchPlugin(id: "calendar", name: "Apple & Google Calendar", description: "Your day at a glance. View your upcoming meetings and schedule natively in the expanded notch.", assetImageName: "calendar_logo", category: .productivity, isPremium: false, storageKey: "enableCalendar"),
        WaveNotchPlugin(id: "canvas", name: "Canvas LMS", description: "Stay on top of your coursework. Get transient notch alerts for upcoming assignment deadlines and newly posted grades.", assetImageName: "canvas_logo", category: .productivity, isPremium: false, storageKey: "enableCanvas"),
        WaveNotchPlugin(id: "gmail", name: "Gmail", description: "Quickly preview the subject and sender of unread emails without opening your web browser.", assetImageName: "gmail_logo", category: .productivity, isPremium: false, storageKey: "enableGmail"),
        
        // ⚙️ SYSTEM
        WaveNotchPlugin(id: "weather", name: "Local Weather", description: "Live local temperature, AQI, and upcoming rain alerts right in the menu bar.", assetImageName: "weather_logo", category: .system, isPremium: false, storageKey: "enableWeather"),
        WaveNotchPlugin(id: "battery", name: "Smart Battery", description: "Get critical warnings when your Mac, Magic Mouse, or AirPods drop below 20%.", assetImageName: "battery_logo", category: .system, isPremium: false, storageKey: "enableBattery")
    ]
}