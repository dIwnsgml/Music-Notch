import SwiftUI
import ApplicationServices

struct OnboardingView: View {
    private let totalPages = 8
    private let lyricsPageIndex = 4
    private let pluginsPageIndex = 5

    @State private var currentPage = 0
    @State private var hasAccessibilityAccess = AXIsProcessTrusted()
    @State private var selectedPluginIDs: Set<String> = initialOnboardingPluginSelection()
    @State private var hasVisitedPluginPage = false

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("enableAnalytics") private var enableAnalytics = true
    @AppStorage("hideNotchOnLockScreen") private var hideNotchOnLockScreen = false

    @AppStorage("themeBackgroundType") private var themeBackgroundType = "preset"
    @AppStorage("themePresetID") private var themePresetID = ThemePreset.defaultID
    @AppStorage("themeBackgroundOpacity") private var themeBackgroundOpacity = 1.0
    @AppStorage("themeBackgroundHoverOnly") private var themeBackgroundHoverOnly = false
    @AppStorage("themeGlassyWidgets") private var themeGlassyWidgets = true

    @AppStorage("showSongChangeBanner") private var showSongChangeBanner = true
    @AppStorage("showBannerOnControl") private var showBannerOnControl = true
    @AppStorage("showLyrics") private var showLyrics = true
    @AppStorage("showBannerLyrics") private var showBannerLyrics = true
    @AppStorage("notch_pets_enabled") private var notchPetsEnabled = false

    @AppStorage("enableAppleMusic") private var enableAppleMusic = false
    @AppStorage("enableSpotify") private var enableSpotify = false
    @AppStorage("enableChrome") private var enableChrome = false
    @AppStorage("enableBrave") private var enableBrave = false
    @AppStorage("enableEdge") private var enableEdge = false
    @AppStorage("enableSafari") private var enableSafari = false

    private var selectedTheme: ThemePreset {
        ThemePreset.preset(id: themePresetID)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch currentPage {
                case 0: welcomePage
                case 1: permissionsPage
                case 2: themePage
                case 3: integrationsPage
                case 4: lyricsPage
                case 5: pluginsPage
                case 6: essentialsPage
                case 7: finishPage
                default: EmptyView()
                }
            }
            .id(currentPage)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)

            Divider()

            footer
        }
        .frame(width: 720, height: 560)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            hasAccessibilityAccess = AXIsProcessTrusted()
            if themeBackgroundType.isEmpty {
                applyTheme(ThemePreset.preset(id: ThemePreset.defaultID))
            }
            handlePageState()
        }
        .onDisappear {
            stopLyricsDemo()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasAccessibilityAccess = AXIsProcessTrusted()
        }
        .onChange(of: currentPage) { _, _ in handlePageState() }
        .onChange(of: showLyrics) { _, _ in updateLyricsDemoState(preferredBanner: "lyrics") }
        .onChange(of: showBannerLyrics) { _, _ in updateLyricsDemoState(preferredBanner: "lyrics") }
        .onChange(of: showSongChangeBanner) { _, _ in updateLyricsDemoState(preferredBanner: "song") }
        .onChange(of: showBannerOnControl) { _, _ in updateLyricsDemoState(preferredBanner: "mediaControl") }
    }

    private var footer: some View {
        HStack(spacing: 18) {
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(width: index == currentPage ? 22 : 8, height: 8)
                        .animation(.spring(response: 0.30, dampingFraction: 0.80), value: currentPage)
                }
            }

            Spacer()

            if currentPage > 0 {
                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        currentPage -= 1
                    }
                }
            }

            Button(action: advanceOrFinish) {
                Text(primaryButtonTitle)
                    .font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(currentPage == 1 && !hasAccessibilityAccess ? .secondary : .accentColor)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var primaryButtonTitle: String {
        if currentPage == totalPages - 1 { return "Get Started" }
        if currentPage == 0 { return "Set Up WaveNotch" }
        if currentPage == 1 && !hasAccessibilityAccess { return "Skip for now" }
        return "Continue"
    }

    private var welcomePage: some View {
        OnboardingPage(
            symbol: "waveform",
            symbolColor: .orange,
            title: "Welcome to WaveNotch",
            subtitle: "Set up your notch dashboard, themes, live lyrics, plugins, pets, and system glanceables in a few steps."
        ) {
            HStack(spacing: 22) {
                onboardingNotchPreview

                VStack(alignment: .leading, spacing: 14) {
                    OnboardingFeatureRow(icon: "music.note", color: .orange, title: "Music and lyrics", desc: "Control playback, view synced lyrics, and search alternate lyric sources.")
                    OnboardingFeatureRow(icon: "square.grid.2x2", color: .purple, title: "Dashboard plugins", desc: "Choose productivity, media, system, and utility widgets for the expanded notch.")
                    OnboardingFeatureRow(icon: "speedometer", color: .teal, title: "System glanceables", desc: "Track weather, hardware, batteries, network speed, screen capture, and more.")
                    OnboardingFeatureRow(icon: "pawprint.fill", color: .pink, title: "Notch Pets", desc: "Enable a small animated companion that moves around the notch and dashboard.")
                }
            }
            .padding(.top, 6)
        }
    }

    private var onboardingNotchPreview: some View {
        ZStack {
            ThemePresetBackground(presetID: themePresetID)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 48, height: 48)
                        .overlay(Image(systemName: "music.note").font(.system(size: 22, weight: .bold)))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Now Playing")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white.opacity(0.65))
                        Text("WaveNotch")
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(.white)
                    }

                    Spacer()
                }

                HStack(spacing: 26) {
                    Image(systemName: "backward.fill")
                    Image(systemName: "pause.fill")
                    Image(systemName: "forward.fill")
                    Image(systemName: "repeat")
                }
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)

                Capsule()
                    .fill(Color.white.opacity(0.24))
                    .frame(height: 8)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.72))
                            .frame(width: 96, height: 8)
                    }
            }
            .padding(22)
        }
        .frame(width: 290, height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.22), radius: 18, y: 10)
    }

    private var permissionsPage: some View {
        OnboardingPage(
            symbol: hasAccessibilityAccess ? "checkmark.shield.fill" : "hand.raised.fill",
            symbolColor: hasAccessibilityAccess ? .green : .blue,
            title: "Allow media controls",
            subtitle: "Accessibility lets WaveNotch read media state and send skip, pause, and play commands."
        ) {
            VStack(spacing: 16) {
                HStack(spacing: 14) {
                    Image(systemName: hasAccessibilityAccess ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(hasAccessibilityAccess ? .green : .orange)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(hasAccessibilityAccess ? "Access granted" : "Access not granted yet")
                            .font(.system(size: 16, weight: .bold))
                        Text(hasAccessibilityAccess ? "You can continue." : "You can skip this now and enable it later in Settings.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if !hasAccessibilityAccess {
                        Button("Open System Settings") {
                            requestAccess()
                        }
                    }
                }
                .padding(18)
                .background(panelBackground)

                Text("In System Settings, enable WaveNotch under Privacy & Security > Accessibility.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 560)
        }
    }

    private var themePage: some View {
        OnboardingPage(
            symbol: "paintbrush.pointed.fill",
            symbolColor: .pink,
            title: "Choose your theme",
            subtitle: "Pick a default background now. You can still use custom colors or photos from Settings later."
        ) {
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    ThemePresetBackground(presetID: themePresetID)
                        .frame(width: 260, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )

                    Text(selectedTheme.name)
                        .font(.system(size: 22, weight: .bold))
                    Text(selectedTheme.subtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)

                    Toggle("Use glassy widget backgrounds", isOn: $themeGlassyWidgets)
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.top, 4)
                }
                .frame(width: 270, alignment: .leading)

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(112), spacing: 12), count: 3), spacing: 12) {
                    ForEach(onboardingThemePresets) { preset in
                        OnboardingThemeCard(
                            preset: preset,
                            isSelected: themeBackgroundType == "preset" && themePresetID == preset.id
                        ) {
                            applyTheme(preset)
                        }
                    }
                }
            }
            .frame(maxWidth: 650)
        }
    }

    private var onboardingThemePresets: [ThemePreset] {
        [
            ThemePreset.preset(id: "venturaGlow"),
            ThemePreset.preset(id: "tahoeBlue"),
            ThemePreset.preset(id: "sequoiaPrism"),
            ThemePreset.preset(id: "sonomaRibbon"),
            ThemePreset.preset(id: "tahoeDay"),
            ThemePreset.preset(id: "cherryBlossom")
        ]
    }

    private var integrationsPage: some View {
        OnboardingPage(
            symbol: "puzzlepiece.extension.fill",
            symbolColor: .green,
            title: "Connect your media",
            subtitle: "Enable the apps and browsers you use. Browser toggles allow WaveNotch to detect music playing in tabs."
        ) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Native Players")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.secondary)
                    OnboardingToggleRow(icon: "music.note", title: "Apple Music", isOn: $enableAppleMusic)
                    OnboardingToggleRow(icon: "speaker.wave.2.fill", title: "Spotify", isOn: $enableSpotify)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(panelBackground)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Browsers")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.secondary)
                    OnboardingToggleRow(icon: "globe", title: "Chrome", isOn: $enableChrome)
                    OnboardingToggleRow(icon: "shield.fill", title: "Brave", isOn: $enableBrave)
                    OnboardingToggleRow(icon: "safari.fill", title: "Safari", isOn: $enableSafari)
                    OnboardingToggleRow(icon: "globe.americas.fill", title: "Edge", isOn: $enableEdge)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(panelBackground)
            }
            .frame(maxWidth: 600)
        }
    }

    private var lyricsPage: some View {
        OnboardingPage(
            symbol: "quote.bubble.fill",
            symbolColor: .blue,
            title: "Choose your lyrics behavior",
            subtitle: "Watch the actual notch while you toggle these. It is playing a temporary mock song for setup."
        ) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    Label("Now previewing on the notch", systemImage: "arrow.up.to.line.compact")
                        .font(.system(size: 15, weight: .black))
                    Text("The compact notch is temporarily showing Last Night on Earth with the same banner behavior these settings control.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 10) {
                        OnboardingCompactFeatureRow(icon: "music.note", color: .blue, title: "Mock song", desc: "Last Night on Earth")
                        OnboardingCompactFeatureRow(icon: "text.quote", color: .cyan, title: "Lyrics line", desc: "We keep moving through the night")
                        OnboardingCompactFeatureRow(icon: "sparkles", color: .purple, title: "Live preview", desc: "Changes update the notch instantly.")
                    }
                    .padding(.top, 4)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(panelBackground)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Display")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.secondary)
                    OnboardingToggleRow(icon: "text.quote", title: "Show lyrics in the player", isOn: $showLyrics)
                    OnboardingToggleRow(icon: "captions.bubble.fill", title: "Show lyric banner near the notch", isOn: $showBannerLyrics)
                    OnboardingToggleRow(icon: "music.note.tv", title: "Show song title on track change", isOn: $showSongChangeBanner)
                    OnboardingToggleRow(icon: "rectangle.and.hand.point.up.left.fill", title: "Show banner on media controls", isOn: $showBannerOnControl)
                }
                .padding(18)
                .frame(width: 272, alignment: .topLeading)
                .background(panelBackground)
            }
            .frame(maxWidth: 620)

            Text("Leaving this page stops the temporary preview. Real playback and lyric search are not modified.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 580)
        }
    }

    private var pluginsPage: some View {
        OnboardingPage(
            symbol: "square.grid.2x2.fill",
            symbolColor: .purple,
            title: "Pick your starting plugins",
            subtitle: "Select the widgets you want installed and enabled on the expanded dashboard."
        ) {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Label("\(selectedPluginIDs.count) selected", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Recommended") {
                        selectedPluginIDs = Set(onboardingPluginOptions.filter { $0.isRecommended }.map(\.id))
                    }
                    Button("Select All") {
                        selectedPluginIDs = Set(onboardingPluginOptions.map(\.id))
                    }
                    Button("Clear") {
                        selectedPluginIDs.removeAll()
                    }
                }

                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(onboardingPluginOptions) { option in
                            OnboardingPluginCard(
                                option: option,
                                isSelected: selectedPluginIDs.contains(option.id)
                            ) {
                                togglePlugin(option)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: 214)
            }
            .frame(maxWidth: 640)
        }
    }

    private var essentialsPage: some View {
        OnboardingPage(
            symbol: "slider.horizontal.3",
            symbolColor: .purple,
            title: "Set the essentials",
            subtitle: "These defaults control how visible and interactive WaveNotch feels day to day."
        ) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Behavior")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.secondary)
                    OnboardingToggleRow(icon: "pawprint.fill", title: "Enable Notch Pets", isOn: $notchPetsEnabled)
                    OnboardingToggleRow(icon: "lock.display", title: "Hide notch on lock screen", isOn: $hideNotchOnLockScreen)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(panelBackground)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Quick Controls")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.secondary)
                    OnboardingCompactFeatureRow(icon: "hand.draw.fill", color: .purple, title: "Swipe or scroll", desc: "Skip tracks from the notch.")
                    OnboardingCompactFeatureRow(icon: "cursorarrow.click.2", color: .blue, title: "Double click", desc: "Open the active media app.")
                    OnboardingCompactFeatureRow(icon: "keyboard", color: .orange, title: "Control + Command + H", desc: "Hide or show WaveNotch.")
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(panelBackground)
            }
            .frame(maxWidth: 620)
        }
    }

    private var finishPage: some View {
        OnboardingPage(
            symbol: "sparkles",
            symbolColor: .yellow,
            title: "You are ready",
            subtitle: "WaveNotch will run from the menu bar. Play music, hover near the notch, and tune the rest from Settings."
        ) {
            VStack(spacing: 18) {
                HStack(spacing: 14) {
                    ThemePresetBackground(presetID: themePresetID)
                        .frame(width: 92, height: 58)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Theme: \(selectedTheme.name)")
                            .font(.system(size: 14, weight: .bold))
                        Text("\(selectedPluginIDs.count) plugins selected. Media apps, pets, lyrics, and layout can be changed anytime.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(16)
                .background(panelBackground)

                Toggle("Share anonymous crash and usage data", isOn: $enableAnalytics)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: 420)
            }
            .frame(maxWidth: 540)
        }
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
    }

    private func advanceOrFinish() {
        if currentPage >= totalPages - 1 {
            finishOnboarding()
        } else {
            withAnimation(.easeInOut(duration: 0.22)) {
                currentPage += 1
            }
        }
    }

    private func applyTheme(_ preset: ThemePreset) {
        themePresetID = preset.id
        themeBackgroundType = "preset"
        themeBackgroundOpacity = 1.0
        themeBackgroundHoverOnly = false
    }

    private func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        hasAccessibilityAccess = AXIsProcessTrusted()
    }

    private func handlePageState() {
        preparePluginPageIfNeeded()
        updateLyricsDemoState()
    }

    private func preparePluginPageIfNeeded() {
        guard currentPage == pluginsPageIndex, !hasVisitedPluginPage else { return }
        hasVisitedPluginPage = true
        selectedPluginIDs = recommendedOnboardingPluginIDs
    }

    private var recommendedOnboardingPluginIDs: Set<String> {
        Set(onboardingPluginOptions.filter { $0.isRecommended }.map(\.id))
    }

    private var defaultLyricsDemoBannerMode: String {
        if showBannerOnControl { return "mediaControl" }
        if showSongChangeBanner { return "song" }
        if showBannerLyrics { return "lyrics" }
        return "none"
    }

    private func updateLyricsDemoState(preferredBanner: String? = nil) {
        guard currentPage == lyricsPageIndex else {
            stopLyricsDemo()
            return
        }

        NotificationCenter.default.post(
            name: .onboardingLyricsDemoChanged,
            object: nil,
            userInfo: [
                "active": true,
                "showLyrics": showLyrics,
                "showBannerLyrics": showBannerLyrics,
                "showSongChangeBanner": showSongChangeBanner,
                "showBannerOnControl": showBannerOnControl,
                "preferredBanner": preferredBanner ?? defaultLyricsDemoBannerMode
            ]
        )
    }

    private func stopLyricsDemo() {
        NotificationCenter.default.post(
            name: .onboardingLyricsDemoChanged,
            object: nil,
            userInfo: ["active": false]
        )
    }

    private func togglePlugin(_ option: OnboardingPluginOption) {
        if selectedPluginIDs.contains(option.id) {
            selectedPluginIDs.remove(option.id)
        } else {
            selectedPluginIDs.insert(option.id)
        }
    }

    private func applySelectedPlugins() {
        let defaults = UserDefaults.standard

        defaults.set(true, forKey: "plugin_player_enabled")

        for option in onboardingPluginOptions {
            let selected = selectedPluginIDs.contains(option.id)
            defaults.set(selected, forKey: "\(option.storagePrefix)_installed")
            defaults.set(selected, forKey: "\(option.storagePrefix)_enabled")
        }

        DashboardManager.shared.refreshWidgets()
    }

    private func finishOnboarding() {
        applySelectedPlugins()
        hasCompletedOnboarding = true
        OnboardingWindowManager.shared.close()
    }
}

private struct OnboardingPluginOption: Identifiable {
    let id: String
    let name: String
    let description: String
    let category: String
    let icon: String
    let color: Color
    let storagePrefix: String
    let isRecommended: Bool
}

private let onboardingPluginOptions: [OnboardingPluginOption] = [
    OnboardingPluginOption(id: "pomodoro_timer", name: "Pomodoro", description: "Study sessions, breaks, banners, and focus reminders.", category: "Focus", icon: "timer", color: .red, storagePrefix: "plugin_pomodoro_timer", isRecommended: true),
    OnboardingPluginOption(id: "tasks", name: "Tasks", description: "Reminders-style tasks with due dates, notes, and alerts.", category: "Focus", icon: "checklist", color: .blue, storagePrefix: "plugin_tasks", isRecommended: true),
    OnboardingPluginOption(id: "clipboard_history", name: "Clipboard", description: "Recent text, images, and copied files in one place.", category: "Utility", icon: "doc.on.clipboard.fill", color: .purple, storagePrefix: "plugin_clipboard_history", isRecommended: false),
    OnboardingPluginOption(id: "file_tray", name: "File Tray", description: "Drop, hold, and drag files back out when you need them.", category: "Utility", icon: "tray.full.fill", color: .cyan, storagePrefix: "plugin_file_tray", isRecommended: false),
    OnboardingPluginOption(id: "kaomoji_board", name: "Kaomoji", description: "One-click emoji and text faces for fast copying.", category: "Utility", icon: "face.smiling.fill", color: .pink, storagePrefix: "plugin_kaomoji_board", isRecommended: false),
    OnboardingPluginOption(id: "weather", name: "Weather", description: "Current conditions, feels-like temperature, humidity, and wind.", category: "Glance", icon: "sun.max.fill", color: .yellow, storagePrefix: "plugin_weather", isRecommended: false),
    OnboardingPluginOption(id: "hardware_hud", name: "Hardware HUD", description: "CPU cores, memory pressure, and internal temperature.", category: "Glance", icon: "cpu.fill", color: .teal, storagePrefix: "plugin_hardware_hud", isRecommended: false),
    OnboardingPluginOption(id: "bluetooth_battery", name: "Batteries", description: "Bluetooth device battery rings with optional Mac battery.", category: "Glance", icon: "battery.100.bolt", color: .green, storagePrefix: "plugin_bluetooth_battery", isRecommended: false),
    OnboardingPluginOption(id: "network_speed", name: "Network Speed", description: "Live upload and download speedometer.", category: "Glance", icon: "arrow.up.arrow.down.circle.fill", color: .mint, storagePrefix: "plugin_network_speed", isRecommended: false),
    OnboardingPluginOption(id: "screen_capture", name: "Screen Capture", description: "Screenshot and recording controls from the notch.", category: "Utility", icon: "record.circle", color: .orange, storagePrefix: "plugin_screen_capture", isRecommended: false),
    OnboardingPluginOption(id: "spotify_queue", name: "Spotify Queue", description: "Upcoming Spotify tracks with quick play actions.", category: "Music", icon: "list.bullet", color: .green, storagePrefix: "plugin_spotify_queue", isRecommended: false),
    OnboardingPluginOption(id: "spotify_playlists", name: "Spotify Playlists", description: "Saved Spotify playlists on the dashboard.", category: "Music", icon: "music.note.list", color: .green, storagePrefix: "plugin_spotify_playlists", isRecommended: false),
    OnboardingPluginOption(id: "youtube_queue", name: "YouTube Queue", description: "Queue view for YouTube and YouTube Music.", category: "Music", icon: "play.rectangle.fill", color: .red, storagePrefix: "plugin_youtube_queue", isRecommended: false),
    OnboardingPluginOption(id: "youtube_playlists", name: "YouTube Playlists", description: "YouTube Music playlist shortcuts.", category: "Music", icon: "rectangle.stack.fill", color: .red, storagePrefix: "plugin_youtube_playlists", isRecommended: false),
    OnboardingPluginOption(id: "turntable_player", name: "Turntable", description: "Animated vinyl view for the currently playing song.", category: "Music", icon: "record.circle", color: .brown, storagePrefix: "plugin_turntable_player", isRecommended: false),
    OnboardingPluginOption(id: "cassette_tape", name: "Cassette Tape", description: "Animated cassette with cover art and tape reels.", category: "Music", icon: "rectangle.roundedtop.fill", color: .orange, storagePrefix: "plugin_cassette_tape", isRecommended: true),
    OnboardingPluginOption(id: "google_calendar", name: "Calendar", description: "Upcoming calendar events in the dashboard.", category: "Focus", icon: "calendar", color: .indigo, storagePrefix: "plugin_google_calendar", isRecommended: false)
]

private func initialOnboardingPluginSelection() -> Set<String> {
    let defaults = UserDefaults.standard
    let hasExistingPluginChoices = onboardingPluginOptions.contains {
        defaults.object(forKey: "\($0.storagePrefix)_installed") != nil
            || defaults.object(forKey: "\($0.storagePrefix)_enabled") != nil
    }

    if !hasExistingPluginChoices {
        return Set(onboardingPluginOptions.filter { $0.isRecommended }.map(\.id))
    }

    return Set(onboardingPluginOptions.filter {
        defaults.bool(forKey: "\($0.storagePrefix)_installed")
            || defaults.bool(forKey: "\($0.storagePrefix)_enabled")
    }.map(\.id))
}

private struct OnboardingPage<Content: View>: View {
    let symbol: String
    let symbolColor: Color
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(symbolColor.opacity(0.16))
                        .frame(width: 64, height: 64)
                    Image(systemName: symbol)
                        .font(.system(size: 27, weight: .bold))
                        .foregroundColor(symbolColor)
                }

                VStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 28, weight: .black))
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .frame(maxWidth: 560)
                }
            }

            content

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 34)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }
}

private struct OnboardingPluginCard: View {
    let option: OnboardingPluginOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(option.color.opacity(isSelected ? 0.24 : 0.14))
                    Image(systemName: option.icon)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(option.color)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(option.name)
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Text(option.category)
                            .font(.system(size: 9, weight: .black))
                            .foregroundColor(option.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(option.color.opacity(0.14), in: Capsule())

                        Spacer(minLength: 0)
                    }

                    Text(option.description)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isSelected ? option.color : .secondary.opacity(0.45))
            }
            .padding(12)
            .frame(minHeight: 76, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? option.color.opacity(0.13) : Color.white.opacity(0.055))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? option.color.opacity(0.70) : Color.white.opacity(0.10), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct OnboardingCompactFeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let desc: String

    var body: some View {
        HStack(alignment: .center, spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(color.opacity(0.14))
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(color)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                Text(desc)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct OnboardingThemeCard: View {
    let preset: ThemePreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack(alignment: .bottomLeading) {
                    ThemePresetBackground(presetID: preset.id)
                        .frame(width: 112, height: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.45), radius: 4, y: 1)
                            .padding(6)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.14), lineWidth: isSelected ? 3 : 1)
                )

                Text(preset.name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(width: 112)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct OnboardingToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .semibold))
        }
        .toggleStyle(.switch)
    }
}

private struct OnboardingFeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let desc: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(color.opacity(0.14))
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(color)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                Text(desc)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}
