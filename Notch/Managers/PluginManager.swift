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
            assetImageName: nil, // Use SF Symbol for now
            category: .media,
            storageKeyBase: "plugin_spotify_queue"
        ),
        WaveNotchPlugin(
            id: "spotify_playlists",
            name: "Spotify Playlists",
            description: "Quickly access and switch between your favorite Spotify playlists with one tap.",
            iconName: "music.note.list",
            assetImageName: nil,
            category: .media,
            storageKeyBase: "plugin_spotify_playlists"
        ),
        WaveNotchPlugin(
            id: "turntable_player",
            name: "Turntable Player",
            description: "Show the current song as a realistic spinning vinyl turntable with album-art label and animated tonearm.",
            iconName: "record.circle",
            assetImageName: nil,
            category: .media,
            storageKeyBase: "plugin_turntable_player"
        ),
        WaveNotchPlugin(
            id: "cassette_tape",
            name: "Cassette Tape",
            description: "Show the current song as an animated cassette tape with spinning reels, moving tape, album art, and track info.",
            iconName: "recordingtape",
            assetImageName: nil,
            category: .media,
            storageKeyBase: "plugin_cassette_tape"
        ),
        WaveNotchPlugin(
            id: "youtube_queue",
            name: "YouTube Music Queue",
            description: "View and manage your current YouTube Music play queue directly in the notch.",
            iconName: "play.square.stack",
            assetImageName: nil,
            category: .media,
            storageKeyBase: "plugin_youtube_queue"
        ),
        WaveNotchPlugin(
            id: "youtube_playlists",
            name: "YouTube Music Playlists",
            description: "Quickly access your YouTube Music library and switch between playlists.",
            iconName: "play.rectangle.on.rectangle",
            assetImageName: nil,
            category: .media,
            storageKeyBase: "plugin_youtube_playlists"
        ),
        WaveNotchPlugin(
            id: "google_calendar",
            name: "Google Calendar",
            description: "View your upcoming events and schedule directly in the notch. Supports multiple calendars and provides timely meeting alerts.",
            iconName: "calendar",
            assetImageName: nil,
            category: .productivity,
            storageKeyBase: "plugin_google_calendar"
        ),
        WaveNotchPlugin(
            id: "pomodoro_timer",
            name: "Pomodoro Timer",
            description: "A focused study timer with work sessions, short breaks, long breaks, and quick controls directly in the notch.",
            iconName: "timer",
            assetImageName: nil,
            category: .productivity,
            storageKeyBase: "plugin_pomodoro_timer"
        ),
        WaveNotchPlugin(
            id: "clipboard_history",
            name: "Clipboard History",
            description: "Keep recent copied text and links available directly in the notch.",
            iconName: "doc.on.clipboard",
            assetImageName: nil,
            category: .productivity,
            storageKeyBase: "plugin_clipboard_history"
        ),
        WaveNotchPlugin(
            id: "file_tray",
            name: "File Tray",
            description: "Pin files and folders in the notch for quick opening, Finder reveal, and one-click copying.",
            iconName: "tray.full.fill",
            assetImageName: nil,
            category: .productivity,
            storageKeyBase: "plugin_file_tray"
        ),
        WaveNotchPlugin(
            id: "tasks",
            name: "Tasks",
            description: "Reminders-style lists with dates, flags, priority, tags, notes, subtasks, search, and completion.",
            iconName: "checkmark.circle.fill",
            assetImageName: nil,
            category: .productivity,
            storageKeyBase: "plugin_tasks"
        ),
        WaveNotchPlugin(
            id: "kaomoji_board",
            name: "Kaomoji & Emoji Board",
            description: "One-click copying for kaomoji, text faces, symbols, and frequently used emoji.",
            iconName: "face.smiling",
            assetImageName: nil,
            category: .productivity,
            storageKeyBase: "plugin_kaomoji_board"
        ),
        WaveNotchPlugin(
            id: "weather",
            name: "Weather",
            description: "Real-time weather conditions, temperature, and short forecasts for your chosen location.",
            iconName: "cloud.sun.fill",
            assetImageName: nil,
            category: .system,
            storageKeyBase: "plugin_weather"
        ),
        WaveNotchPlugin(
            id: "hardware_hud",
            name: "Hardware HUD",
            description: "Glance at per-core CPU usage, memory pressure, and internal temperature directly in the notch.",
            iconName: "cpu.fill",
            assetImageName: nil,
            category: .system,
            storageKeyBase: "plugin_hardware_hud"
        ),
        WaveNotchPlugin(
            id: "bluetooth_battery",
            name: "Bluetooth Batteries",
            description: "Show battery rings for connected Bluetooth devices, with an option to include your Mac battery.",
            iconName: "battery.100.bolt",
            assetImageName: nil,
            category: .system,
            storageKeyBase: "plugin_bluetooth_battery"
        ),
        WaveNotchPlugin(
            id: "screen_capture",
            name: "Screen Capture",
            description: "Take fullscreen, area, window, and clipboard screenshots, plus quick screen recordings from the notch.",
            iconName: "camera.viewfinder",
            assetImageName: nil,
            category: .system,
            storageKeyBase: "plugin_screen_capture"
        ),
        WaveNotchPlugin(
            id: "network_speed",
            name: "Network Speed",
            description: "Watch real-time upload and download speed so you can tell if Wi-Fi is dropping or a site is slow.",
            iconName: "arrow.up.arrow.down.circle.fill",
            assetImageName: nil,
            category: .system,
            storageKeyBase: "plugin_network_speed"
        )
    ]
}
