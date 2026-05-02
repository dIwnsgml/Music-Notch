import SwiftUI

struct PluginStoreView: View {
    @StateObject private var manager = PluginManager.shared
    @State private var selectedPlugin: WaveNotchPlugin?
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                    ForEach(manager.plugins) { plugin in
                        PluginCardView(plugin: plugin, onSetup: {
                            selectedPlugin = plugin
                        })
                        .onTapGesture {
                            selectedPlugin = plugin
                        }
                    }
                }
                .padding(24)
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
                        title: "Show timer in collapsed notch",
                        description: "Use a clock progress icon on the left and the remaining time on the right.",
                        key: "pomodoro_show_notch_timer",
                        defaultValue: true
                    )
                    Divider().opacity(0.15)
                    PluginSettingToggle(
                        title: "Show timer banner while running",
                        description: "Show the active Pomodoro countdown in the collapsed banner row.",
                        key: "pomodoro_show_timer_banner",
                        defaultValue: false
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
        case let id where id.contains("weather"):
            return .orange
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
