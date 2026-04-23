import SwiftUI

struct PluginStoreView: View {
    @StateObject private var manager = PluginManager.shared
    @State private var selectedPlugin: WaveNotchPlugin?
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                    ForEach(manager.plugins) { plugin in
                        PluginCardView(plugin: plugin)
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
    
    @AppStorage var isInstalled: Bool
    @AppStorage var isEnabled: Bool
    
    init(plugin: WaveNotchPlugin) {
        self.plugin = plugin
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
            
            HStack {
                Spacer()
                PluginActionButton(plugin: plugin)
            }
        }
        .padding(16)
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
                        spotifyAuthSection
                    } else if plugin.id == "google_calendar" {
                        googleAuthSection
                    }
                    
                    pluginSettingsSection
                }
                .padding(32)
            }
        }
        .frame(width: 500, height: 600)
    }
    
    private var spotifyAuthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account Connection")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.secondary)
            
            VStack {
                if !SpotifyAuthManager.shared.accessToken.isEmpty {
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
                            SpotifyAuthManager.shared.accessToken = ""
                            SpotifyAuthManager.shared.refreshToken = ""
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                } else {
                    Button(action: {
                        SpotifyAuthManager.shared.authenticate { _ in }
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
                        key: "plugin_spotify_queue_auto_hide"
                    )
                } else if plugin.id == "spotify_playlists" {
                    PluginSettingToggle(
                        title: "Auto-hide when not playing Spotify",
                        description: "The playlists widget will only appear when Spotify is active.",
                        key: "plugin_spotify_playlists_auto_hide"
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
        case let id where id.contains("weather"):
            return .orange
        default:
            return .accentColor
        }
    }
}

struct PluginSettingToggle: View {
    let title: String
    let description: String
    let key: String
    
    @AppStorage var isOn: Bool
    
    init(title: String, description: String, key: String) {
        self.title = title
        self.description = description
        self.key = key
        self._isOn = AppStorage(wrappedValue: false, key)
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
    
    @AppStorage var isInstalled: Bool
    @AppStorage var isEnabled: Bool
    @State private var isSimulating = false
    
    init(plugin: WaveNotchPlugin) {
        self.plugin = plugin
        self._isInstalled = AppStorage(wrappedValue: false, plugin.installedKey)
        self._isEnabled = AppStorage(wrappedValue: false, plugin.enabledKey)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if isSimulating {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 60)
            } else if !isInstalled {
                Button("Install Plugin") {
                    simulateAction {
                        isInstalled = true
                        isEnabled = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            } else {
                Button(isEnabled ? "Disable" : "Enable") {
                    withAnimation { isEnabled.toggle() }
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
