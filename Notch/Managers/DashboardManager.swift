import SwiftUI
import Combine

enum NotchWidgetType: String, Codable, CaseIterable, Identifiable {
    case player
    case spotifyQueue
    case spotifyPlaylists
    case turntable
    case cassette
    case youtubeQueue
    case youtubePlaylists
    case calendar
    case pomodoro
    case clipboard
    case fileTray
    case tasks
    case kaomoji
    case weather
    case hardwareHUD
    case screenCapture
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .player: return "Music Player"
        case .spotifyQueue: return "Spotify Queue"
        case .spotifyPlaylists: return "Spotify Playlists"
        case .turntable: return "Turntable Player"
        case .cassette: return "Cassette Tape"
        case .youtubeQueue: return "YouTube Music Queue"
        case .youtubePlaylists: return "YouTube Music Playlists"
        case .calendar: return "Calendar"
        case .pomodoro: return "Pomodoro Timer"
        case .clipboard: return "Clipboard History"
        case .fileTray: return "File Tray"
        case .tasks: return "Tasks"
        case .kaomoji: return "Kaomoji & Emoji Board"
        case .weather: return "Weather"
        case .hardwareHUD: return "Hardware HUD"
        case .screenCapture: return "Screen Capture"
        }
    }
    
    var isInstalled: Bool {
        switch self {
        case .player: return true // Built-in
        case .spotifyQueue: return UserDefaults.standard.bool(forKey: "plugin_spotify_queue_installed")
        case .spotifyPlaylists: return UserDefaults.standard.bool(forKey: "plugin_spotify_playlists_installed")
        case .turntable: return UserDefaults.standard.bool(forKey: "plugin_turntable_player_installed")
        case .cassette: return UserDefaults.standard.bool(forKey: "plugin_cassette_tape_installed")
        case .youtubeQueue: return UserDefaults.standard.bool(forKey: "plugin_youtube_queue_installed")
        case .youtubePlaylists: return UserDefaults.standard.bool(forKey: "plugin_youtube_playlists_installed")
        case .calendar: return UserDefaults.standard.bool(forKey: "plugin_google_calendar_installed")
        case .pomodoro: return UserDefaults.standard.bool(forKey: "plugin_pomodoro_timer_installed")
        case .clipboard: return UserDefaults.standard.bool(forKey: "plugin_clipboard_history_installed")
        case .fileTray: return UserDefaults.standard.bool(forKey: "plugin_file_tray_installed")
        case .tasks: return UserDefaults.standard.bool(forKey: "plugin_tasks_installed")
        case .kaomoji: return UserDefaults.standard.bool(forKey: "plugin_kaomoji_board_installed")
        case .weather: return UserDefaults.standard.bool(forKey: "plugin_weather_installed")
        case .hardwareHUD: return UserDefaults.standard.bool(forKey: "plugin_hardware_hud_installed")
        case .screenCapture: return UserDefaults.standard.bool(forKey: "plugin_screen_capture_installed")
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
        
        // ⚡️ NEW: Observe media source changes to handle auto-hiding logic
        NowPlayingManager.shared.$lastActiveBrowser
            .sink { [weak self] _ in
                self?.refreshWidgets()
            }
            .store(in: &cancellables)

        // ⚡️ NEW: Observe playing state for turntable/cassette auto-hide
        NowPlayingManager.shared.$isPlaying
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshWidgets()
            }
            .store(in: &cancellables)
        
        refreshWidgets()
    }
    
    func getWidgetOrder() -> [NotchWidgetType] {
        var fullOrder: [NotchWidgetType]
        
        if let data = UserDefaults.standard.data(forKey: "dashboard_widget_order"),
           let savedOrder = try? JSONDecoder().decode([NotchWidgetType].self, from: data) {
            
            // Ensure all enum cases are accounted for (e.g., if new plugins were added in an update)
            fullOrder = savedOrder
            let missing = NotchWidgetType.allCases.filter { !fullOrder.contains($0) }
            fullOrder.append(contentsOf: missing)
        } else {
            fullOrder = NotchWidgetType.allCases
        }
        
        return fullOrder.filter { $0.isInstalled }
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
        let turntableEnabled = UserDefaults.standard.bool(forKey: "plugin_turntable_player_enabled")
        let cassetteEnabled = UserDefaults.standard.bool(forKey: "plugin_cassette_tape_enabled")
        let ytQueueEnabled = UserDefaults.standard.bool(forKey: "plugin_youtube_queue_enabled")
        let ytPlaylistsEnabled = UserDefaults.standard.bool(forKey: "plugin_youtube_playlists_enabled")
        let calendarEnabled = UserDefaults.standard.bool(forKey: "plugin_google_calendar_enabled")
        let pomodoroEnabled = UserDefaults.standard.bool(forKey: "plugin_pomodoro_timer_enabled")
        let clipboardEnabled = UserDefaults.standard.bool(forKey: "plugin_clipboard_history_enabled")
        let fileTrayEnabled = UserDefaults.standard.bool(forKey: "plugin_file_tray_enabled")
        let tasksEnabled = UserDefaults.standard.bool(forKey: "plugin_tasks_enabled")
        let kaomojiEnabled = UserDefaults.standard.bool(forKey: "plugin_kaomoji_board_enabled")
        let weatherEnabled = UserDefaults.standard.bool(forKey: "plugin_weather_enabled")
        let hardwareHUDEnabled = UserDefaults.standard.bool(forKey: "plugin_hardware_hud_enabled")
        let screenCaptureEnabled = UserDefaults.standard.bool(forKey: "plugin_screen_capture_enabled")
        if clipboardEnabled {
            _ = ClipboardHistoryManager.shared
        }
        
        // ⚡️ NEW: Auto-hide logic for Spotify Plugins
        let spotifyQueueAutoHide = UserDefaults.standard.object(forKey: "plugin_spotify_queue_auto_hide") as? Bool ?? true
        let spotifyPlaylistsAutoHide = UserDefaults.standard.object(forKey: "plugin_spotify_playlists_auto_hide") as? Bool ?? true
        
        // ⚡️ Auto-hide logic for YouTube Plugins
        let ytQueueAutoHide = UserDefaults.standard.object(forKey: "plugin_youtube_queue_auto_hide") as? Bool ?? true
        let ytPlaylistsAutoHide = UserDefaults.standard.object(forKey: "plugin_youtube_playlists_auto_hide") as? Bool ?? true
        
        // ⚡️ Auto-hide logic for Turntable and Cassette
        let turntableAutoHide = UserDefaults.standard.object(forKey: "plugin_turntable_player_auto_hide") as? Bool ?? true
        let cassetteAutoHide = UserDefaults.standard.object(forKey: "plugin_cassette_tape_auto_hide") as? Bool ?? true
        
        let lastBrowser = NowPlayingManager.shared.lastActiveBrowser ?? ""
        let isSpotifyActive = lastBrowser == "SpotifyNative" || lastBrowser.contains("Spotify")
        let isYTActive = lastBrowser.contains("YouTube Music") || lastBrowser.contains("Music.YouTube")
        
        // ⚡️ Only hide if NO music is detected at all (even if paused)
        let isMusicDetected = NowPlayingManager.shared.isPlaying || NowPlayingManager.shared.currentSong != "No Music"
        
        let order = getWidgetOrder()
        var widgets: [NotchWidgetType] = []
        
        for widget in order {
            switch widget {
            case .player: if playerEnabled { widgets.append(.player) }
            case .spotifyQueue:
                if queueEnabled {
                    if spotifyQueueAutoHide && !isSpotifyActive {
                        // Skip adding it if auto-hide is on and Spotify isn't playing
                    } else {
                        widgets.append(.spotifyQueue)
                    }
                }
            case .spotifyPlaylists:
                if playlistsEnabled {
                    if spotifyPlaylistsAutoHide && !isSpotifyActive {
                        // Skip adding it
                    } else {
                        widgets.append(.spotifyPlaylists)
                    }
                }
            case .turntable:
                if turntableEnabled {
                    if turntableAutoHide && !isMusicDetected {
                        // Skip adding it
                    } else {
                        widgets.append(.turntable)
                    }
                }
            case .cassette:
                if cassetteEnabled {
                    if cassetteAutoHide && !isMusicDetected {
                        // Skip adding it
                    } else {
                        widgets.append(.cassette)
                    }
                }
            case .youtubeQueue:
                if ytQueueEnabled {
                    if ytQueueAutoHide && !isYTActive {
                        // Skip adding it
                    } else {
                        widgets.append(.youtubeQueue)
                    }
                }
            case .youtubePlaylists:
                if ytPlaylistsEnabled {
                    if ytPlaylistsAutoHide && !isYTActive {
                        // Skip adding it
                    } else {
                        widgets.append(.youtubePlaylists)
                    }
                }
            case .calendar: if calendarEnabled { widgets.append(.calendar) }
            case .pomodoro: if pomodoroEnabled { widgets.append(.pomodoro) }
            case .clipboard: if clipboardEnabled { widgets.append(.clipboard) }
            case .fileTray: if fileTrayEnabled { widgets.append(.fileTray) }
            case .tasks: if tasksEnabled { widgets.append(.tasks) }
            case .kaomoji: if kaomojiEnabled { widgets.append(.kaomoji) }
            case .weather: if weatherEnabled { widgets.append(.weather) }
            case .hardwareHUD: if hardwareHUDEnabled { widgets.append(.hardwareHUD) }
            case .screenCapture: if screenCaptureEnabled { widgets.append(.screenCapture) }
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
