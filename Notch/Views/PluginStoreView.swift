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
                .padding(20)
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
                // Icon
                PluginIcon(plugin: plugin, size: 44)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(plugin.name)
                        .font(.system(size: 13, weight: .bold))
                    Text(plugin.category.rawValue)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isInstalled && isEnabled {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
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
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isEnabled ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

struct PluginDetailView: View {
    let plugin: WaveNotchPlugin
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top) {
                PluginIcon(plugin: plugin, size: 80)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(plugin.name)
                        .font(.system(size: 20, weight: .bold))
                    Text(plugin.category.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Text(plugin.description)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Management")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    PluginActionButton(plugin: plugin)
                }
            }
            
            if plugin.id == "spotify_queue" {
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Account Connection")
                        .font(.headline)
                    
                    if !SpotifyAuthManager.shared.accessToken.isEmpty {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Connected to Spotify")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.green)
                                Text("Your playback and queue are syncing.")
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
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Plugin Settings")
                        .font(.headline)
                    
                    PluginSettingToggle(
                        title: "Auto-hide when not playing Spotify",
                        description: "The queue widget will only appear in your dashboard when Spotify is the active media source.",
                        key: "plugin_spotify_queue_auto_hide"
                    )
                }
            } else if plugin.id == "spotify_playlists" {
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Account Connection")
                        .font(.headline)
                    
                    if !SpotifyAuthManager.shared.accessToken.isEmpty {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Connected to Spotify")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.green)
                                Text("Your playlists are ready to use.")
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
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Plugin Settings")
                        .font(.headline)
                    
                    PluginSettingToggle(
                        title: "Auto-hide when not playing Spotify",
                        description: "The playlists widget will only appear in your dashboard when Spotify is the active media source.",
                        key: "plugin_spotify_playlists_auto_hide"
                    )
                }
            } else if plugin.id == "google_calendar" {
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Account Connection")
                        .font(.headline)
                    
                    if GoogleCalendarManager.shared.isAuthenticated {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Connected to Google")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.green)
                                Text("Your events are syncing in the background.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Log Out") {
                                GoogleCalendarManager.shared.accessToken = ""
                                GoogleCalendarManager.shared.refreshToken = ""
                                GoogleCalendarManager.shared.isAuthenticated = false
                                GoogleCalendarManager.shared.upcomingEvents = []
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    } else {
                        Button(action: {
                            GoogleCalendarManager.shared.authenticate { success in
                                if success { print("Google Auth Success!") }
                            }
                        }) {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.plus")
                                Text("Sign in with Google")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                }
            }
            
            Spacer()
        }
        .padding(30)
        .frame(width: 450, height: 450)
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
                    .frame(width: size * 0.63, height: size * 0.63)
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
        HStack(alignment: .top) {
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
                Button("Install") {
                    simulateAction {
                        isInstalled = true
                        isEnabled = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                // Enable/Disable Toggle
                Button(isEnabled ? "Disable" : "Enable") {
                    if !isEnabled && plugin.id == "spotify_plus" {
                        // Trigger Spotify Auth if not already authenticated
                        SpotifyAuthManager.shared.authenticate { success in
                            if success {
                                withAnimation {
                                    isEnabled = true
                                }
                            }
                        }
                    } else {
                        withAnimation {
                            isEnabled.toggle()
                        }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                // Uninstall
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
                .controlSize(.small)
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
