import SwiftUI
import AppKit

private enum PluginStoreCategoryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case media = "Media & Music"
    case productivity = "Productivity"
    case system = "System Utilities"

    var id: String { rawValue }

    var category: PluginCategory? {
        switch self {
        case .all: return nil
        case .media: return .media
        case .productivity: return .productivity
        case .system: return .system
        }
    }
}

struct PluginStoreView: View {
    @StateObject private var manager = PluginManager.shared
    @State private var selectedPlugin: WaveNotchPlugin?
    @State private var selectedCategory: PluginStoreCategoryFilter = .all
    @State private var searchText = ""

    private var filteredPlugins: [WaveNotchPlugin] {
        manager.plugins.filter { plugin in
            let matchesCategory = selectedCategory.category.map { plugin.category == $0 } ?? true
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else { return matchesCategory }

            let searchableText = [
                plugin.name,
                plugin.description,
                plugin.category.rawValue
            ].joined(separator: " ").localizedCaseInsensitiveContains(query)

            return matchesCategory && searchableText
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Picker("Category", selection: $selectedCategory) {
                    ForEach(PluginStoreCategoryFilter.allCases) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    TextField("Search plugins", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 4)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                    ForEach(filteredPlugins) { plugin in
                        PluginCardView(plugin: plugin, onSetup: {
                            selectedPlugin = plugin
                        })
                        .onTapGesture {
                            selectedPlugin = plugin
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
                .padding(24)
                .animation(.spring(response: 0.28, dampingFraction: 0.86), value: selectedCategory)
                .animation(.easeInOut(duration: 0.18), value: searchText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(item: $selectedPlugin) { plugin in
            PluginDetailView(plugin: plugin)
        }
    }
}

struct PluginCardView: View {
    let plugin: WaveNotchPlugin
    var onSetup: (() -> Void)? = nil
    
    @AppStorage var isInstalled: Bool
    @AppStorage var isEnabled: Bool
    
    init(plugin: WaveNotchPlugin, onSetup: (() -> Void)? = nil) {
        self.plugin = plugin
        self.onSetup = onSetup
        self._isInstalled = AppStorage(wrappedValue: false, plugin.installedKey)
        self._isEnabled = AppStorage(wrappedValue: false, plugin.enabledKey)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                PluginIcon(plugin: plugin, size: 48)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(plugin.name)
                        .font(.system(size: 14, weight: .bold))
                    Text(plugin.category.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isInstalled && isEnabled {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .shadow(color: .green.opacity(0.5), radius: 4)
                }
            }
            
            Text(plugin.description)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .frame(height: 32, alignment: .top)
            
            Spacer(minLength: 12)
            
            if isInstalled {
                VStack(spacing: 8) {
                    Button(action: { onSetup?() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "gearshape.fill")
                            Text("Setup")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.regular)
                    
                    PluginActionButton(plugin: plugin, onInstall: {
                        onSetup?()
                    })
                }
            } else {
                VStack(spacing: 8) {
                    PluginActionButton(plugin: plugin, onInstall: {
                        onSetup?()
                    })
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isEnabled ? Color.accentColor.opacity(0.2) : Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}

struct PluginDetailView: View {
    let plugin: WaveNotchPlugin
    @Environment(\.dismiss) var dismiss

    @State private var showManualSetup = false // ⚡️ Added state for manual setup toggle
    @ObservedObject var spotifyManager = SpotifyAuthManager.shared // ⚡️ Reactivity fix

    @AppStorage("enableChrome") var enableChrome = false
    @AppStorage("enableBrave") var enableBrave = false
    @AppStorage("enableEdge") var enableEdge = false
    @AppStorage("enableSafari") var enableSafari = false

    var hasAnyBrowser: Bool { enableChrome || enableBrave || enableEdge || enableSafari }    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .center, spacing: 20) {
                PluginIcon(plugin: plugin, size: 80)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(plugin.name)
                        .font(.system(size: 24, weight: .bold))
                    Text(plugin.category.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    PluginActionButton(plugin: plugin)
                        .padding(.top, 4)
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(32)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(plugin.description)
                            .font(.system(size: 14))
                            .lineSpacing(4)
                    }
                    
                    if plugin.id.contains("spotify") {
                        spotifyDeveloperSection
                        spotifyAuthSection
                    } else if plugin.id == "google_calendar" {
                        googleAuthSection
                    } else if plugin.id.contains("youtube") {
                        youtubeAuthSection
                    }
                    
                    pluginSettingsSection
                }
                .padding(32)
            }
        }
        .frame(width: 500, height: 600)
    }
    
    private var spotifyDeveloperSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("1. Developer Setup (Required)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Why is this required?")
                        .font(.system(size: 12, weight: .bold))
                    Text("Spotify strictly limits new apps to 25 people during development. To allow everyone to use WaveNotch, you must create your own 'App' in their dashboard.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                if !hasAnyBrowser {
                    VStack(alignment: .leading, spacing: 10) {
                        StepRow(number: 1, text: "Go to [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard)")
                        StepRow(number: 2, text: "Log in and click 'Create App'")
                        StepRow(number: 3, text: "Set Name to 'WaveNotch' (or anything)")
                        StepRow(number: 4, text: "Set Redirect URI to: wavenotch://callback")
                        StepRow(number: 5, text: "Check 'Web API' and 'iOS' boxes")
                        StepRow(number: 6, text: "Save, go to Settings, and copy 'Client ID'")
                    }
                } else if !showManualSetup {
                    VStack(alignment: .leading, spacing: 10) {
                        StepRow(number: 1, text: "Click 'Automate Setup' below.")
                        StepRow(number: 2, text: "WaveNotch will open your browser and fill out the forms.")
                        StepRow(number: 3, text: "The Client ID will be automatically saved here when done!")
                    }

                    Button(action: {
                        spotifyManager.automateSetup()
                    }) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text("Automate Setup for Me")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(.purple)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        StepRow(number: 1, text: "Go to [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard)")
                        StepRow(number: 2, text: "Log in and click 'Create App'")
                        StepRow(number: 3, text: "Set Name to 'WaveNotch' (or anything)")
                        StepRow(number: 4, text: "Set Redirect URI to: wavenotch://callback")
                        StepRow(number: 5, text: "Check 'Web API' and 'iOS' boxes")
                        StepRow(number: 6, text: "Save, go to Settings, and copy 'Client ID'")
                    }
                }

                if hasAnyBrowser {
                    Button(action: {
                        withAnimation { showManualSetup.toggle() }
                    }) {
                        Text(showManualSetup ? "Hide Manual Setup" : "Set up manually instead")
                            .font(.system(size: 12, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
                    VStack(alignment: .leading, spacing: 6) {
                    Text("Your Client ID:")
                        .font(.system(size: 12, weight: .bold))

                    TextField("Enter Client ID", text: $spotifyManager.userClientID)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                    }
                    .padding(.top, 4)
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(
                    RoundedRectangle(cornerRadius: 12)
                    .stroke(spotifyManager.userClientID.isEmpty ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                    }
                    }

                    private var spotifyAuthSection: some View {
        let hasClientID = spotifyManager.hasValidClientID

        return VStack(alignment: .leading, spacing: 12) {
            Text("2. Account Connection")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(hasClientID ? .secondary : .secondary.opacity(0.5))

            VStack {
                if !hasClientID {
                    VStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("Developer Setup Required")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.gray)
                        Text("Please provide your Spotify Client ID above before you can connect your account.")
                            .font(.system(size: 11))
                            .foregroundColor(.gray.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    } else if !spotifyManager.accessToken.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Connected to Spotify")
                                .font(.system(size: 13, weight: .medium))
                            Text("Your playback and data are syncing perfectly.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Log Out") {
                            spotifyManager.accessToken = ""
                            spotifyManager.refreshToken = ""
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    } else {
                    Button(action: {
                        spotifyManager.authenticate { _ in }
                    }) {
                        HStack {
                            Image(systemName: "music.note")
                            Text("Sign in with Spotify")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    }
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .opacity(hasClientID ? 1.0 : 0.5)
                    }
                    }    
    private var googleAuthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account Connection")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.secondary)
            
            VStack {
                if GoogleCalendarManager.shared.isAuthenticated {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Connected to Google")
                                .font(.system(size: 13, weight: .medium))
                            Text("Your events are syncing in the background.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Log Out") {
                            GoogleCalendarManager.shared.accessToken = ""
                            GoogleCalendarManager.shared.refreshToken = ""
                            GoogleCalendarManager.shared.isAuthenticated = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                } else {
                    Button(action: {
                        GoogleCalendarManager.shared.authenticate { _ in }
                    }) {
                        HStack {
                            Image(systemName: "calendar")
                            Text("Sign in with Google")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    private var youtubeAuthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account Connection")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.secondary)
            
            VStack {
                if YouTubeMusicManager.shared.isAuthenticated {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Connected to YouTube")
                                .font(.system(size: 13, weight: .medium))
                            Text("Your library is syncing.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Log Out") {
                            YouTubeMusicManager.shared.accessToken = ""
                            YouTubeMusicManager.shared.refreshToken = ""
                            YouTubeMusicManager.shared.isAuthenticated = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                } else {
                    Button(action: {
                        YouTubeMusicManager.shared.authenticate { _ in }
                    }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("Sign in with Google")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    private var pluginSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Plugin Settings")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.secondary)
            
            VStack(spacing: 0) {
                if plugin.id == "spotify_queue" {
                    PluginSettingToggle(
                        title: "Auto-hide when not playing Spotify",
                        description: "The queue widget will only appear when Spotify is active.",
                        key: "plugin_spotify_queue_auto_hide",
                        defaultValue: true
                    )
                } else if plugin.id == "spotify_playlists" {
                    PluginSettingToggle(
                        title: "Auto-hide when not playing Spotify",
                        description: "The playlists widget will only appear when Spotify is active.",
                        key: "plugin_spotify_playlists_auto_hide",
                        defaultValue: true
                    )
                } else if plugin.id == "youtube_queue" {
                    PluginSettingToggle(
                        title: "Auto-hide when not playing YouTube Music",
                        description: "The queue widget will only appear when YouTube Music is active.",
                        key: "plugin_youtube_queue_auto_hide",
                        defaultValue: true
                    )
                } else if plugin.id == "youtube_playlists" {
                    PluginSettingToggle(
                        title: "Auto-hide when not playing YouTube Music",
                        description: "The playlists widget will only appear when YouTube Music is active.",
                        key: "plugin_youtube_playlists_auto_hide",
                        defaultValue: true
                    )
                } else if plugin.id == "pomodoro_timer" {
                    PluginSettingToggle(
                        title: "Show timer icon in collapsed notch",
                        description: "Use a circular progress icon on the left of the notch when running.",
                        key: "pomodoro_show_notch_timer",
                        defaultValue: true
                    )
                    Divider().opacity(0.15)
                    PluginSettingToggle(
                        title: "Show countdown text next to notch",
                        description: "Display the remaining time on the right side of the notch.",
                        key: "pomodoro_show_time_text",
                        defaultValue: false
                    )
                    Divider().opacity(0.15)
                    PluginSettingToggle(
                        title: "Show timer banner while running",
                        description: "Show the active Pomodoro countdown in the collapsed banner row.",
                        key: "pomodoro_show_timer_banner",
                        defaultValue: true
                    )
                    Divider().opacity(0.15)
                    PluginSettingToggle(
                        title: "Sound when mode changes",
                        description: "Play a short alert when focus, break, or long break finishes.",
                        key: "pomodoro_sound_on_mode_change",
                        defaultValue: true
                    )
                    Divider().opacity(0.15)
                    PluginSettingToggle(
                        title: "Show banner when mode changes",
                        description: "Show a 3-second completion banner when Pomodoro switches modes.",
                        key: "pomodoro_show_mode_change_banner",
                        defaultValue: true
                    )
                    Divider().opacity(0.15)
                    PomodoroSettingStepper(
                        title: "Focus Session",
                        key: "pomodoro_focus_minutes",
                        range: 5...90,
                        defaultValue: 25,
                        suffix: "min"
                    )
                    Divider().opacity(0.15)
                    PomodoroSettingStepper(
                        title: "Short Break",
                        key: "pomodoro_short_break_minutes",
                        range: 1...30,
                        defaultValue: 5,
                        suffix: "min"
                    )
                    Divider().opacity(0.15)
                    PomodoroSettingStepper(
                        title: "Long Break",
                        key: "pomodoro_long_break_minutes",
                        range: 5...60,
                        defaultValue: 15,
                        suffix: "min"
                    )
                    Divider().opacity(0.15)
                    PomodoroSettingStepper(
                        title: "Long Break Every",
                        key: "pomodoro_long_break_every",
                        range: 2...8,
                        defaultValue: 4,
                        suffix: "rounds"
                    )
                } else if plugin.id == "weather" {
                    WeatherPluginSettingsView()
                } else if plugin.id == "hardware_hud" {
                    HardwareHUDPluginSettingsView()
                } else if plugin.id == "bluetooth_battery" {
                    BluetoothBatteryPluginSettingsView()
                } else if plugin.id == "screen_capture" {
                    ScreenCapturePluginSettingsView()
                } else if plugin.id == "network_speed" {
                    NetworkSpeedPluginSettingsView()
                } else if plugin.id == "turntable_player" {
                    TurntablePluginSettingsView()
                } else if plugin.id == "cassette_tape" {
                    CassetteTapePluginSettingsView()
                } else if plugin.id == "clipboard_history" {
                    ClipboardPluginSettingsView()
                } else if plugin.id == "file_tray" {
                    FileTrayPluginSettingsView()
                } else if plugin.id == "tasks" {
                    TasksPluginSettingsView()
                } else if plugin.id == "kaomoji_board" {
                    KaomojiPluginSettingsView()
                } else {
                    Text("No additional settings for this plugin.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }
}

struct StepRow: View {
    let number: Int
    let text: LocalizedStringKey

    var body: some View {        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.accentColor.opacity(0.3)))
            
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct PluginIcon: View {
    let plugin: WaveNotchPlugin
    let size: CGFloat
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27)
                .fill(brandColor.opacity(0.1))
                .frame(width: size, height: size)
            
            if let asset = plugin.assetImageName, NSImage(named: asset) != nil {
                Image(asset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.6, height: size * 0.6)
            } else {
                Image(systemName: plugin.iconName)
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundColor(brandColor)
            }
        }
    }
    
    private var brandColor: Color {
        switch plugin.id {
        case let id where id.contains("spotify"):
            return .green
        case let id where id.contains("calendar"):
            return .blue
        case let id where id.contains("pomodoro"):
            return .red
        case let id where id.contains("cassette"):
            return .orange
        case let id where id.contains("clipboard"):
            return .purple
        case let id where id.contains("file_tray"):
            return .cyan
        case let id where id.contains("tasks"):
            return .mint
        case let id where id.contains("kaomoji"):
            return .pink
        case let id where id.contains("weather"):
            return .orange
        case let id where id.contains("hardware_hud"):
            return .mint
        case let id where id.contains("bluetooth_battery"):
            return .green
        case let id where id.contains("screen_capture"):
            return .cyan
        case let id where id.contains("network_speed"):
            return .cyan
        default:
            return .accentColor
        }
    }
}

struct PomodoroSettingStepper: View {
    let title: String
    let key: String
    let range: ClosedRange<Int>
    let suffix: String

    @AppStorage var value: Int

    private var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.maximumFractionDigits = 0
        return formatter
    }

    init(title: String, key: String, range: ClosedRange<Int>, defaultValue: Int, suffix: String) {
        self.title = title
        self.key = key
        self.range = range
        self.suffix = suffix
        self._value = AppStorage(wrappedValue: defaultValue, key)
    }

    var body: some View {
        Stepper(value: clampedValue, in: range, step: 1) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                HStack(spacing: 6) {
                    TextField("", value: clampedValue, formatter: numberFormatter)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 58)
                    Text(suffix)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            value = clamp(value)
        }
    }

    private var clampedValue: Binding<Int> {
        Binding(
            get: { clamp(value) },
            set: { value = clamp($0) }
        )
    }

    private func clamp(_ rawValue: Int) -> Int {
        min(max(rawValue, range.lowerBound), range.upperBound)
    }
}

struct WeatherPluginSettingsView: View {
    @AppStorage("weather_use_current_location") private var useCurrentLocation = true
    @AppStorage("weather_location_query") private var locationQuery = "New York"
    @AppStorage("weather_temperature_unit") private var temperatureUnit = "fahrenheit"
    @StateObject private var weather = WeatherManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Use current location")
                        .font(.system(size: 13, weight: .medium))
                    Text(weather.locationStatusText)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Toggle("", isOn: $useCurrentLocation)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .onChange(of: useCurrentLocation) { _, _ in
                WeatherManager.shared.fetchWeather(force: true)
            }

            Divider().opacity(0.15)

            if useCurrentLocation {
                Button {
                    WeatherManager.shared.fetchWeather(force: true)
                } label: {
                    HStack {
                        Image(systemName: "location")
                        Text("Update Current Location")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Text("Uses macOS Location Services. If permission is denied, Weather falls back to the manual city below.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)

                Divider().opacity(0.15)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(useCurrentLocation ? "Fallback City" : "Location")
                    .font(.system(size: 13, weight: .medium))
                TextField("City, ZIP, or place name", text: $locationQuery)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
            }

            Divider().opacity(0.15)

            Picker("Temperature Unit", selection: $temperatureUnit) {
                Text("Fahrenheit").tag("fahrenheit")
                Text("Celsius").tag("celsius")
            }
            .pickerStyle(.segmented)
            .onChange(of: temperatureUnit) { _, _ in
                WeatherManager.shared.fetchWeather(force: true)
            }

            Button {
                WeatherManager.shared.fetchWeather(force: true)
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh Weather")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Text("Weather data by Open-Meteo.")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

struct HardwareHUDPluginSettingsView: View {
    @AppStorage("hardware_hud_refresh_interval") private var refreshInterval = 2.0
    @StateObject private var hardware = HardwareHUDManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Refresh Rate")
                        .font(.system(size: 13, weight: .medium))
                    Text("Lower intervals feel more live, higher intervals use less CPU.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Picker("", selection: $refreshInterval) {
                    Text("1 sec").tag(1.0)
                    Text("2 sec").tag(2.0)
                    Text("5 sec").tag(5.0)
                    Text("10 sec").tag(10.0)
                }
                .pickerStyle(.menu)
                .frame(width: 92)
            }

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Show per-core bars",
                description: "Display individual CPU core usage instead of only the average.",
                key: "hardware_hud_show_per_core",
                defaultValue: true
            )

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Show internal temperature",
                description: "Reads SMC temperature sensors when available, otherwise uses macOS thermal state.",
                key: "hardware_hud_show_temperature",
                defaultValue: true
            )

            Divider().opacity(0.15)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Current Reading")
                        .font(.system(size: 13, weight: .medium))
                    Text(currentReadingText)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    hardware.refresh()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .onAppear {
            hardware.refresh()
        }
    }

    private var currentReadingText: String {
        let snapshot = hardware.snapshot
        let cpu = "\(Int(snapshot.cpuAverage * 100))% CPU"
        let memory = "\(formatBytes(snapshot.memoryUsedBytes)) / \(formatBytes(snapshot.memoryTotalBytes)) memory"
        let temperature = snapshot.temperatureCelsius.map { "\(Int($0.rounded()))°C" } ?? thermalStateText(snapshot.thermalState)
        return "\(cpu) · \(memory) · \(temperature)"
    }

    private func thermalStateText(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "Nominal"
        case .fair: return "Warm"
        case .serious: return "Hot"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 10 {
            return "\(Int(gb.rounded())) GB"
        }
        return String(format: "%.1f GB", gb)
    }
}

struct BluetoothBatteryPluginSettingsView: View {
    @AppStorage("bluetooth_battery_show_laptop") private var showLaptopBattery = true
    @StateObject private var manager = BluetoothBatteryManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PluginSettingToggle(
                title: "Show Mac battery",
                description: "Include the MacBook's internal battery as the first battery ring.",
                key: "bluetooth_battery_show_laptop",
                defaultValue: true
            )

            Divider().opacity(0.15)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Detected Devices")
                        .font(.system(size: 13, weight: .medium))
                    Text(detectedText)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    manager.refresh()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Text("Bluetooth battery percentages come from macOS Bluetooth and IOKit battery services. Some devices may require Bluetooth permission before percentages appear.")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear {
            manager.refresh()
        }
        .onChange(of: showLaptopBattery) { _, _ in
            manager.refresh()
        }
    }

    private var detectedText: String {
        guard !manager.devices.isEmpty else { return "No Bluetooth battery devices found." }
        return manager.devices
            .map { device in
                device.percent.map { "\(device.name) \($0)%" } ?? "\(device.name) --"
            }
            .joined(separator: ", ")
    }
}

struct ScreenCapturePluginSettingsView: View {
    @AppStorage("screen_capture_save_location") private var saveLocation = "desktop"
    @AppStorage("screen_capture_image_format") private var imageFormat = "png"
    @StateObject private var capture = ScreenCaptureManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Screen Recording Permission")
                        .font(.system(size: 13, weight: .medium))
                    Text(capture.hasScreenCapturePermission ? "Ready for screenshots and recordings." : "Required before this plugin can capture the screen.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Button(capture.hasScreenCapturePermission ? "Open Settings" : "Allow") {
                    capture.hasScreenCapturePermission ? capture.openScreenRecordingSettings() : capture.requestPermission()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Divider().opacity(0.15)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Save Location")
                        .font(.system(size: 13, weight: .medium))
                    Text("Where captured files are saved.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Picker("", selection: $saveLocation) {
                    Text("Desktop").tag("desktop")
                    Text("Downloads").tag("downloads")
                    Text("Pictures").tag("pictures")
                }
                .pickerStyle(.menu)
                .frame(width: 126)
            }

            Divider().opacity(0.15)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Screenshot Format")
                        .font(.system(size: 13, weight: .medium))
                    Text("Used for screen, area, and window captures.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Picker("", selection: $imageFormat) {
                    Text("PNG").tag("png")
                    Text("JPG").tag("jpg")
                    Text("TIFF").tag("tiff")
                    Text("PDF").tag("pdf")
                }
                .pickerStyle(.menu)
                .frame(width: 126)
            }

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Hide notch while capturing",
                description: "Temporarily hides WaveNotch so it does not appear in screenshots or recordings.",
                key: "screen_capture_hide_notch",
                defaultValue: true
            )

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Include cursor in screenshots",
                description: "Adds the pointer to fullscreen and clipboard captures.",
                key: "screen_capture_include_cursor",
                defaultValue: false
            )

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Play capture sound",
                description: "Use the native macOS screenshot sound for still captures.",
                key: "screen_capture_play_sound",
                defaultValue: false
            )

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Open after capture",
                description: "Open screenshots in Preview and recordings in QuickTime Player.",
                key: "screen_capture_open_after_capture",
                defaultValue: false
            )

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Add captures to File Tray",
                description: "New files are added to File Tray after successful captures.",
                key: "screen_capture_add_to_file_tray",
                defaultValue: false
            )

            Divider().opacity(0.15)

            PomodoroSettingStepper(
                title: "Recording Limit",
                key: "screen_capture_recording_duration",
                range: 0...600,
                defaultValue: 15,
                suffix: "sec"
            )

            Text("Set recording limit to 0 seconds to stop manually from the native recording controls.")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Record microphone audio",
                description: "Uses the default input device during screen recordings.",
                key: "screen_capture_record_audio",
                defaultValue: false
            )

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Show clicks in recordings",
                description: "Displays mouse clicks in captured videos.",
                key: "screen_capture_show_clicks",
                defaultValue: true
            )

            Button {
                capture.openSaveLocation()
            } label: {
                HStack {
                    Image(systemName: "folder")
                    Text("Open Capture Folder")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .onAppear {
            capture.refreshPermissionStatus()
        }
    }
}

struct NetworkSpeedPluginSettingsView: View {
    @AppStorage("network_speed_unit") private var unitMode = "bits"
    @AppStorage("network_speed_refresh_interval") private var refreshInterval = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Speed Unit")
                        .font(.system(size: 13, weight: .medium))
                    Text("Choose how upload and download speeds are displayed.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Picker("", selection: $unitMode) {
                    Text("Bits").tag("bits")
                    Text("Bytes").tag("bytes")
                }
                .pickerStyle(.menu)
                .frame(width: 104)
            }

            Divider().opacity(0.15)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Refresh Rate")
                        .font(.system(size: 13, weight: .medium))
                    Text("Lower values feel more live; higher values use less CPU.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Picker("", selection: $refreshInterval) {
                    Text("0.5 sec").tag(0.5)
                    Text("1 sec").tag(1.0)
                    Text("2 sec").tag(2.0)
                    Text("5 sec").tag(5.0)
                }
                .pickerStyle(.menu)
                .frame(width: 104)
            }
            .onChange(of: refreshInterval) { _, _ in
                NetworkSpeedManager.shared.syncSettings()
            }

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Show mini graph",
                description: "Display a compact upload/download activity graph.",
                key: "network_speed_show_graph",
                defaultValue: true
            )

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Show interface name",
                description: "Show Wi-Fi, Ethernet, VPN, or other active interfaces under the title.",
                key: "network_speed_show_interface",
                defaultValue: true
            )

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Include virtual interfaces",
                description: "Include VPN, peer-to-peer, and other virtual adapters in speed totals.",
                key: "network_speed_include_virtual",
                defaultValue: false
            )
        }
    }
}

struct TurntablePluginSettingsView: View {
    @AppStorage("turntable_spin_speed") private var spinSpeed = 1.0
    @AppStorage("turntable_plinth_style") private var plinthStyle = "graphite"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spin speed")
                            .font(.system(size: 13, weight: .medium))
                        Text("Adjust how fast the record spins while music is playing.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(String(format: "%.1fx", clampedSpinSpeedValue))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    Text("0.5x")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    Slider(value: clampedSpinSpeed, in: 0.5...2.0, step: 0.1)
                        .labelsHidden()
                    Text("2.0x")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            Divider().opacity(0.15)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Record backing")
                        .font(.system(size: 13, weight: .medium))
                    Text("Change the square surface behind the spinning record.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Picker("", selection: $plinthStyle) {
                    Text("Graphite").tag("graphite")
                    Text("Walnut").tag("walnut")
                    Text("Album Color").tag("album")
                    Text("Glass").tag("glass")
                    Text("None").tag("none")
                }
                .pickerStyle(.menu)
                .frame(width: 126)
            }

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Auto-hide when not playing",
                description: "Automatically remove the turntable from the notch when no music is playing.",
                key: "plugin_turntable_player_auto_hide",
                defaultValue: true
            )

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Show control buttons",
                description: "Display previous, play/pause, and next buttons on the turntable.",
                key: "turntable_show_controls",
                defaultValue: false
            )

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Click record to play/pause",
                description: "Toggle playback by clicking the vinyl record.",
                key: "turntable_click_record_toggle",
                defaultValue: true
            )

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Show track info",
                description: "Display the current song information inside the turntable widget.",
                key: "turntable_show_track_info",
                defaultValue: true
            )

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Show song title",
                description: "Show the current song title when track info is enabled.",
                key: "turntable_show_track_title",
                defaultValue: true
            )

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Show artist / author",
                description: "Show the artist or author line when track info is enabled.",
                key: "turntable_show_track_artist",
                defaultValue: true
            )
        }
        .onAppear {
            spinSpeed = clampedSpinSpeedValue
        }
    }

    private var clampedSpinSpeed: Binding<Double> {
        Binding(
            get: { clampedSpinSpeedValue },
            set: { spinSpeed = min(max($0, 0.5), 2.0) }
        )
    }

    private var clampedSpinSpeedValue: Double {
        min(max(spinSpeed, 0.5), 2.0)
    }
}

struct CassetteTapePluginSettingsView: View {
    @AppStorage("cassette_reel_speed") private var reelSpeed = 1.0
    @AppStorage("cassette_label_color") private var labelColor = "orange"
    @AppStorage("cassette_body_color") private var bodyColor = "black"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reel speed")
                            .font(.system(size: 13, weight: .medium))
                        Text("Adjust how fast the cassette reels spin while music is playing.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text(String(format: "%.1fx", clampedReelSpeedValue))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    Text("0.5x")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    Slider(value: clampedReelSpeed, in: 0.5...2.0, step: 0.1)
                        .labelsHidden()
                    Text("2.0x")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            Divider().opacity(0.15)
            
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cassette Body Color")
                        .font(.system(size: 13, weight: .medium))
                    Text("Choose the color theme for the cassette's outer shell.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Picker("", selection: $bodyColor) {
                    Text("Opaque Black").tag("black")
                    Text("Classic White").tag("white")
                    Text("Transparent").tag("transparent")
                    Text("Dynamic (Album Art)").tag("dynamic")
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 240)
            }

            Divider().opacity(0.15)
            
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cassette Label Color")
                        .font(.system(size: 13, weight: .medium))
                    Text("Choose the color theme for the cassette label, or let it match the album art.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Picker("", selection: $labelColor) {
                    Text("Classic Orange").tag("orange")
                    Text("Vintage Red").tag("red")
                    Text("Cobalt Blue").tag("blue")
                    Text("Neon Green").tag("green")
                    Text("Deep Purple").tag("purple")
                    Text("Monochrome").tag("gray")
                    Text("Dynamic (Album Art)").tag("dynamic")
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(maxWidth: 240)
            }

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Auto-hide when not playing",
                description: "Automatically remove the cassette from the notch when no music is playing.",
                key: "plugin_cassette_tape_auto_hide",
                defaultValue: true
            )

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Click cassette to play/pause",
                description: "Toggle playback by clicking the cassette widget.",
                key: "cassette_click_to_toggle",
                defaultValue: true
            )

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Show album cover",
                description: "Display album art on the cassette label.",
                key: "cassette_show_album_cover",
                defaultValue: true
            )

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Show track info",
                description: "Display the current song information on the cassette label.",
                key: "cassette_show_track_info",
                defaultValue: true
            )

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Show song title",
                description: "Show the current song title when track info is enabled.",
                key: "cassette_show_track_title",
                defaultValue: true
            )

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Show artist / author",
                description: "Show the artist or author line when track info is enabled.",
                key: "cassette_show_track_artist",
                defaultValue: true
            )
        }
        .onAppear {
            reelSpeed = clampedReelSpeedValue
        }
    }

    private var clampedReelSpeed: Binding<Double> {
        Binding(
            get: { clampedReelSpeedValue },
            set: { reelSpeed = min(max($0, 0.5), 2.0) }
        )
    }

    private var clampedReelSpeedValue: Double {
        min(max(reelSpeed, 0.5), 2.0)
    }
}

struct ClipboardPluginSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PomodoroSettingStepper(
                title: "History Limit",
                key: "clipboard_history_limit",
                range: 5...100,
                defaultValue: 30,
                suffix: "items"
            )

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Track copied files",
                description: "Save Finder file copies as file references that can be copied back later.",
                key: "clipboard_history_track_files",
                defaultValue: true
            )

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Track copied images",
                description: "Save copied images up to 12 MB with a thumbnail preview.",
                key: "clipboard_history_track_images",
                defaultValue: true
            )

            Divider().opacity(0.15)

            Button(role: .destructive) {
                ClipboardHistoryManager.shared.clearHistory()
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear Clipboard History")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Text("Tracks text, links, files, and images while the plugin is enabled.")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

struct FileTrayPluginSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PomodoroSettingStepper(
                title: "Tray Limit",
                key: "file_tray_limit",
                range: 4...80,
                defaultValue: 24,
                suffix: "items"
            )

            Divider().opacity(0.15)

            Button(role: .destructive) {
                FileTrayManager.shared.clearItems()
            } label: {
                HStack {
                    Image(systemName: "tray.and.arrow.down")
                    Text("Clear File Tray")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Text("Stores file and folder references locally. Files are not duplicated.")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

struct TasksPluginSettingsView: View {
    @AppStorage("tasks_show_completed") private var showCompleted = true
    @AppStorage("tasks_reminder_notifications_enabled") private var reminderNotificationsEnabled = true
    @AppStorage("tasks_reminder_app_banner_enabled") private var reminderAppBannerEnabled = true
    @AppStorage("tasks_detail_display_mode") private var detailDisplayMode = "compact"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PomodoroSettingStepper(
                title: "Reminder Limit",
                key: "tasks_limit",
                range: 5...100,
                defaultValue: 60,
                suffix: "items"
            )

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "Show completed reminders",
                description: "Keep completed reminders visible in All and custom lists.",
                key: "tasks_show_completed",
                defaultValue: true
            )

            Divider().opacity(0.15)

            VStack(alignment: .leading, spacing: 6) {
                Text("Reminder Details")
                    .font(.system(size: 12, weight: .semibold))
                Picker("", selection: $detailDisplayMode) {
                    Text("Compact").tag("compact")
                    Text("Hover").tag("hover")
                    Text("Always").tag("always")
                }
                .pickerStyle(.segmented)
            }

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "macOS notification banner",
                description: "Use Notification Center like other apps, with a standard system banner and sound.",
                key: "tasks_reminder_notifications_enabled",
                defaultValue: true
            )

            Button {
                openMacOSNotificationSettings()
            } label: {
                HStack {
                    Image(systemName: "gearshape.fill")
                    Text("Open macOS Notification Settings")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Divider().opacity(0.15)

            PluginSettingToggle(
                title: "WaveNotch reminder banner",
                description: "Show due reminders inside the notch as a temporary in-app banner.",
                key: "tasks_reminder_app_banner_enabled",
                defaultValue: true
            )

            Divider().opacity(0.15)

            Button {
                TasksManager.shared.sendTestReminderAlerts()
            } label: {
                HStack {
                    Image(systemName: "bell.badge")
                    Text("Send Test Reminder")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Divider().opacity(0.15)

            Button {
                TasksManager.shared.clearCompleted()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle")
                    Text("Clear Completed Reminders")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(role: .destructive) {
                TasksManager.shared.clearAll()
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear All Reminders")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Text("Reminders, lists, tags, notes, priorities, and subtasks are stored locally.")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .onChange(of: showCompleted) { _, _ in
            TasksManager.shared.syncSettings()
        }
        .onChange(of: reminderNotificationsEnabled) { _, _ in
            TasksManager.shared.syncSettings()
        }
        .onChange(of: reminderAppBannerEnabled) { _, _ in
            TasksManager.shared.syncSettings()
        }
    }

    private func openMacOSNotificationSettings() {
        let candidateURLs = [
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=com.jason.WaveNotch",
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.notifications"
        ]

        for rawURL in candidateURLs {
            guard let url = URL(string: rawURL) else { continue }
            if NSWorkspace.shared.open(url) {
                break
            }
        }
    }
}

struct KaomojiPluginSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PomodoroSettingStepper(
                title: "Recent Limit",
                key: "kaomoji_board_recent_limit",
                range: 0...24,
                defaultValue: 12,
                suffix: "items"
            )

            Divider().opacity(0.15)

            Button(role: .destructive) {
                KaomojiBoardManager.shared.clearRecent()
            } label: {
                HStack {
                    Image(systemName: "clock.badge.xmark")
                    Text("Clear Recent")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Text("Recent items are saved locally and copied back as plain text.")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

struct PluginSettingToggle: View {
    let title: String
    let description: String
    let key: String
    
    @AppStorage var isOn: Bool
    
    init(title: String, description: String, key: String, defaultValue: Bool = false) {
        self.title = title
        self.description = description
        self.key = key
        self._isOn = AppStorage(wrappedValue: defaultValue, key)
    }
    
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }
}

struct PluginActionButton: View {
    let plugin: WaveNotchPlugin
    var onInstall: (() -> Void)? = nil
    
    @AppStorage var isInstalled: Bool
    @AppStorage var isEnabled: Bool
    @State private var isSimulating = false
    
    init(plugin: WaveNotchPlugin, onInstall: (() -> Void)? = nil) {
        self.plugin = plugin
        self.onInstall = onInstall
        self._isInstalled = AppStorage(wrappedValue: false, plugin.installedKey)
        self._isEnabled = AppStorage(wrappedValue: false, plugin.enabledKey)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if isSimulating {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
            } else if !isInstalled {
                Button(action: {
                    simulateAction {
                        isInstalled = true
                        isEnabled = true
                        onInstall?()
                    }
                }) {
                    Text("Install Plugin")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            } else {
                Button(action: {
                    withAnimation { isEnabled.toggle() }
                }) {
                    Text(isEnabled ? "Disable" : "Enable")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                
                Button(action: {
                    simulateAction {
                        isInstalled = false
                        isEnabled = false
                    }
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Uninstall Plugin")
            }
        }
    }
    
    private func simulateAction(completion: @escaping () -> Void) {
        isSimulating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSimulating = false
            completion()
        }
    }
}
