import SwiftUI
import PostHog
import ApplicationServices
import ServiceManagement
import AppKit
import KeyboardShortcuts // ⚡️ Import the package
import Sparkle

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case lyrics = "Lyrics & Banner"
    case layout = "Layout" // ⚡️ NEW: Layout Editor
    case shortcuts = "Shortcuts"
    case integrations = "Integrations"
    case plugins = "Plugins"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .lyrics: return "text.quote"
        case .layout: return "square.grid.2x2"
        case .shortcuts: return "keyboard"
        case .integrations: return "puzzlepiece.extension"
        case .plugins: return "app.badge.fill"
        }
    }
}

struct SettingsView: View {
    @AppStorage("lastSettingsTab") var selectedTab: SettingsTab = .general
    @State private var showSidebar = true
    
    // ⚡️ GENERAL
    @AppStorage("collapsedWidth") var collapsedWidth: Double = 300.0
    @AppStorage("showSettingsButton") var showSettingsButton = true
    @AppStorage("enableHoverToExpand") var enableHoverToExpand = true
    @AppStorage("hoverDelay") var hoverDelay: Double = 0.0
    @AppStorage("enableDoubleClickToOpen") var enableDoubleClickToOpen = true
    @AppStorage("launchAtLogin") var launchAtLogin = false
    @AppStorage("showGlowEffect") var showGlowEffect = true
    @AppStorage("invertSwipeDirection") var invertSwipeDirection = true
    @AppStorage("enableAnalytics") var enableAnalytics = true
    
    // ⚡️ LYRICS & BANNER
    @AppStorage("showBannerOnControl") var showBannerOnControl = true
    @AppStorage("bannerDuration") var bannerDuration: Double = 3.5
    @AppStorage("showLyrics") var showLyrics = true
    @AppStorage("showBannerLyrics") var showBannerLyrics = true
    @AppStorage("visibleLyricLines") var visibleLyricLines = 3
    @AppStorage("lyricDimming") var lyricDimming: Double = 0.3
    @AppStorage("lyricBlurAmount") var lyricBlurAmount: Double = 0.4
    @AppStorage("lyricOffset") var lyricOffset: Double = 0.0
    
    @State private var hasAccessibilityAccess = false
    
    // ⚡️ INTEGRATIONS
    @AppStorage("enableCalendar") var enableCalendar = false
    @ObservedObject var calendarManager = CalendarManager.shared
    
    @AppStorage("enableAppleMusic") var enableAppleMusic = false
    @AppStorage("enableSpotify") var enableSpotify = false
    @AppStorage("enableChrome") var enableChrome = false
    @AppStorage("enableBrave") var enableBrave = false
    @AppStorage("enableEdge") var enableEdge = false
    @AppStorage("enableSafari") var enableSafari = false
    
    @State private var isAppleMusicInstalled = true
    @State private var isSpotifyInstalled = false
    @State private var isChromeInstalled = false
    @State private var isBraveInstalled = false
    @State private var isEdgeInstalled = false
    @State private var isSafariInstalled = true
    
    @State private var browserNeedingHelp: String? = nil
    @State private var showHelpAlert = false
    
    @State private var updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    
    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                if showSidebar {
                    VStack(spacing: 0) {
                        List(SettingsTab.allCases, selection: $selectedTab) { tab in
                            Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                        }
                        .listStyle(.sidebar)
                        
                        Divider()
                        
                        // ⚡️ NEW: Bottom Sidebar Actions
                        VStack(spacing: 0) {
                            
                            // Check for Updates Button
                            Button(action: { updaterController.updater.checkForUpdates() }) {
                                HStack {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                    Text("Check for Updates")
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            // Quit Button
                            Button(action: { NSApplication.shared.terminate(nil) }) {
                                HStack {
                                    Image(systemName: "power")
                                    Text("Quit WaveNotch")
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.red)
                            
                            // ⚡️ NEW: Dynamic Version Label
                            let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                            let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                            
                            Text("Version \(appVersion) (\(buildNumber))")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.top, 4)
                                .padding(.bottom, 16)
                        }
                        .background(Color(NSColor.windowBackgroundColor)) // Matches the sidebar background natively
                    }
                    .frame(width: 180)
                    .transition(.move(edge: .leading))
                    Divider()
                }
                
                Group {
                    if selectedTab == .plugins {
                        PluginStoreView()
                    } else if selectedTab == .layout {
                        DashboardSettingsView()
                    } else {
                        Form {
                            switch selectedTab {
                            case .general: generalContent
                            case .lyrics: lyricsContent
                            case .shortcuts: shortcutsContent
                            case .integrations: integrationsContent
                            default: EmptyView()
                            }
                        }
                        .formStyle(.grouped)
                    }
                }
            }
            .navigationTitle(selectedTab.rawValue)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { showSidebar.toggle() } }) {
                        Image(systemName: "sidebar.left")
                    }
                    .help("Toggle Sidebar")
                }
            }
        }
        .frame(width: 650, height: 550)
        .onAppear {
            hasAccessibilityAccess = AXIsProcessTrusted()
            launchAtLogin = SMAppService.mainApp.status == .enabled
            isSpotifyInstalled = checkAppExists(bundleID: "com.spotify.client")
            isChromeInstalled = checkAppExists(bundleID: "com.google.Chrome")
            isBraveInstalled = checkAppExists(bundleID: "com.brave.Browser")
            isEdgeInstalled = checkAppExists(bundleID: "com.microsoft.edgemac")
            calendarManager.checkAccessStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasAccessibilityAccess = AXIsProcessTrusted()
            calendarManager.checkAccessStatus()
        }
        .alert(isPresented: $showHelpAlert) {
            let browser = browserNeedingHelp ?? "Browser"
            let isSafari = browser == "Safari"
            return Alert(
                title: Text("Action Required for \(browser)"),
                message: Text(isSafari ?
                              "1. Open Safari\n2. Click 'Safari' in the menu bar -> 'Settings'\n3. Go to 'Advanced' and check 'Show features for web developers'\n4. Click 'Develop' in the menu bar\n5. Check 'Allow JavaScript from Apple Events'"
                              :
                                "1. Open \(browser)\n2. Click 'View' in the top Mac menu bar\n3. Hover over 'Developer'\n4. Click 'Allow JavaScript from Apple Events'"),
                dismissButton: .default(Text("I've done this!"))
            )
        }
    }
    
    // ---------------------------------------------------------
    // ⌨️ SHORTCUTS TAB
    // ---------------------------------------------------------
    private var shortcutsContent: some View {
        Group {
            Section {
                KeyboardShortcuts.Recorder("Hide / Show WaveNotch", name: .toggleAppVisibility)
            } header: {
                Text("Global Visibility")
            } footer: {
                Text("Completely vanishes the notch from your screen until pressed again.")
            }
            
            Section {
                KeyboardShortcuts.Recorder("Toggle Live Lyrics in Player", name: .toggleLiveLyrics)
                KeyboardShortcuts.Recorder("Toggle Menu Bar Lyrics", name: .toggleBannerLyrics)
                KeyboardShortcuts.Recorder("Toggle Action Banners", name: .toggleBanner)
            } header: {
                Text("Toggles")
            }
            
            Section {
                KeyboardShortcuts.Recorder("Increase Lyric Sync (+0.5s)", name: .increaseOffset)
                KeyboardShortcuts.Recorder("Decrease Lyric Sync (-0.5s)", name: .decreaseOffset)
            } header: {
                Text("Lyric Synchronization")
            }
            
            Section {
                KeyboardShortcuts.Recorder("Increase Visible Lines", name: .increaseLines)
                KeyboardShortcuts.Recorder("Decrease Visible Lines", name: .decreaseLines)
                
                KeyboardShortcuts.Recorder("Increase Hover Delay", name: .increaseDelay)
                KeyboardShortcuts.Recorder("Decrease Hover Delay", name: .decreaseDelay)
            } header: {
                Text("UI Adjustments")
            }
            
            Section {
                Button("Reset All Shortcuts") {
                    KeyboardShortcuts.reset(.toggleAppVisibility, .toggleLiveLyrics, .toggleBannerLyrics, .toggleBanner, .increaseOffset, .decreaseOffset, .increaseLines, .decreaseLines, .increaseDelay, .decreaseDelay)
                }
                .foregroundColor(.red)
            }
        }
    }
    
    // ---------------------------------------------------------
    // ⚙️ GENERAL TAB
    // ---------------------------------------------------------
    private var generalContent: some View {
        Group {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Collapsed Notch Width: \(Int(collapsedWidth))px")
                    HStack(spacing: 8) {
                        Text("200px").font(.caption).foregroundColor(.secondary).frame(width: 40, alignment: .leading)
                        Slider(value: $collapsedWidth, in: 200...400, step: 10).labelsHidden()
                        Text("400px").font(.caption).foregroundColor(.secondary).frame(width: 40, alignment: .trailing)
                    }
                }
                .padding(.vertical, 4)
                Toggle("Show Settings Gear in Expanded View", isOn: $showSettingsButton)
            } header: { Text("Appearance") }
            
            Section {
                Toggle("Expand Automatically on Hover", isOn: $enableHoverToExpand)
                if enableHoverToExpand {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hover Delay: \(hoverDelay, specifier: "%.1f") sec")
                        HStack(spacing: 8) {
                            Text("0.0s").font(.caption).foregroundColor(.secondary).frame(width: 32, alignment: .leading)
                            Slider(value: $hoverDelay, in: 0.0...3.0, step: 0.1).labelsHidden()
                            Text("3.0s").font(.caption).foregroundColor(.secondary).frame(width: 32, alignment: .trailing)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in toggleLaunchAtLogin(enabled: newValue) }
                Toggle("Double-Click Player to Open Media App", isOn: $enableDoubleClickToOpen)
                Toggle("Show Cinematic Glow on Song Change", isOn: $showGlowEffect)
                Toggle("Invert Swipe Direction", isOn: $invertSwipeDirection)
            } header: { Text("App Behavior") }
            
            Section {
                HStack {
                    Text("Accessibility Access")
                    Spacer()
                    if hasAccessibilityAccess {
                        Text("Granted").foregroundColor(.green)
                    } else {
                        Button("Request Access") { requestAccessibilityAccess() }
                    }
                }
            } header: { Text("System Permissions") }
            
            Section {
                Toggle("Share Anonymous Usage Data", isOn: $enableAnalytics)
                    .onChange(of: enableAnalytics) { newValue in
                        if newValue {
                            PostHogSDK.shared.optIn()
                        } else {
                            PostHogSDK.shared.optOut()
                        }
                    }
            } header: {
                Text("Privacy")
            } footer: {
                Text("Helps us improve WaveNotch by sending anonymous launch statistics. We never track your personal data or music history.")
            }
        }
    }
    
    // ---------------------------------------------------------
    // 🎵 LYRICS & BANNER TAB
    // ---------------------------------------------------------
    private var lyricsContent: some View {
        Group {
            Section {
                Toggle("Show Banner on Media Control", isOn: $showBannerOnControl)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Banner Duration: \(bannerDuration, specifier: "%.1f") sec")
                    HStack(spacing: 8) {
                        Text("1.0s").font(.caption).foregroundColor(.secondary).frame(width: 32, alignment: .leading)
                        Slider(value: $bannerDuration, in: 1.0...8.0, step: 0.5).labelsHidden()
                        Text("8.0s").font(.caption).foregroundColor(.secondary).frame(width: 32, alignment: .trailing)
                    }
                }
                .padding(.vertical, 4)
                
            } header: {
                Text("Notch Banner")
            }
            
            Section {
                Toggle("Enable Live Lyrics in Player", isOn: $showLyrics)
                Toggle("Show Continuous Lyrics in Menu Bar", isOn: $showBannerLyrics)
            } header: {
                Text("Lyrics Display")
            }
            
            if showLyrics {
                Section {
                    Picker("Visible Lines", selection: $visibleLyricLines) {
                        Text("1 Line").tag(1)
                        Text("3 Lines").tag(3)
                        Text("5 Lines").tag(5)
                    }
                    .pickerStyle(.segmented)
                    
                    if visibleLyricLines > 1 {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Background Dimming")
                            HStack(spacing: 8) {
                                Text("Light").font(.caption).foregroundColor(.secondary).frame(width: 36, alignment: .leading)
                                Slider(value: $lyricDimming, in: 0.1...0.8, step: 0.1).labelsHidden()
                                Text("Dark").font(.caption).foregroundColor(.secondary).frame(width: 36, alignment: .trailing)
                            }
                        }
                        .padding(.vertical, 4)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Background Blur")
                            HStack(spacing: 8) {
                                Text("None").font(.caption).foregroundColor(.secondary).frame(width: 36, alignment: .leading)
                                Slider(value: $lyricBlurAmount, in: 0.0...2.0, step: 0.2).labelsHidden()
                                Text("Heavy").font(.caption).foregroundColor(.secondary).frame(width: 36, alignment: .trailing)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Lyrics Appearance")
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        let offsetText = lyricOffset == 0.0 ? "0.0 s" : String(format: "%+.1f s", lyricOffset)
                        Text("Sync Offset: \(offsetText)")
                        HStack(spacing: 8) {
                            Text("-8.0s").font(.caption).foregroundColor(.secondary).frame(width: 36, alignment: .leading)
                            Slider(value: $lyricOffset, in: -8.0...8.0, step: 0.5).labelsHidden()
                            Text("+8.0s").font(.caption).foregroundColor(.secondary).frame(width: 36, alignment: .trailing)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Synchronization")
                } footer: {
                    Text("Slide left to delay lyrics, right to make them appear earlier.")
                }
            }
        }
    }
    
    // ---------------------------------------------------------
    // 🧩 INTEGRATIONS TAB
    // ---------------------------------------------------------
    private var integrationsContent: some View {
        Group {
            Section {
                Toggle("Enable Calendar Integration", isOn: $enableCalendar)
                
                if enableCalendar {
                    HStack {
                        Text("Calendar Status")
                        Spacer()
                        if calendarManager.hasAccess {
                            Text("Connected").foregroundColor(.green)
                        } else {
                            Button("Request Access") {
                                calendarManager.requestAccess()
                            }
                        }
                    }
                }
            } header: { Text("Google/Apple Calendar") }
            
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Media Players", systemImage: "play.circle.fill")
                        .font(.headline)
                    
                    Toggle(isOn: $enableAppleMusic) {
                        HStack {
                            Image(systemName: "apple.logo")
                            Text("Apple Music")
                        }
                    }
                    
                    Toggle(isOn: $enableSpotify) {
                        HStack {
                            Image(systemName: "music.note")
                            Text("Spotify")
                        }
                    }
                    .disabled(!isSpotifyInstalled)
                    if !isSpotifyInstalled {
                        Text("Spotify app not detected.").font(.caption2).foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } header: { Text("Supported Apps") }
            
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Web Browsers", systemImage: "safari.fill")
                        .font(.headline)
                    
                    Toggle(isOn: $enableChrome) {
                        HStack {
                            Image(systemName: "globe")
                            Text("Google Chrome")
                        }
                    }
                    .onChange(of: enableChrome) { newValue in if newValue { browserNeedingHelp = "Chrome"; showHelpAlert = true } }
                    
                    Toggle(isOn: $enableBrave) {
                        HStack {
                            Image(systemName: "globe")
                            Text("Brave Browser")
                        }
                    }
                    .onChange(of: enableBrave) { newValue in if newValue { browserNeedingHelp = "Brave"; showHelpAlert = true } }
                    
                    Toggle(isOn: $enableEdge) {
                        HStack {
                            Image(systemName: "globe")
                            Text("Microsoft Edge")
                        }
                    }
                    .onChange(of: enableEdge) { newValue in if newValue { browserNeedingHelp = "Edge"; showHelpAlert = true } }
                    
                    Toggle(isOn: $enableSafari) {
                        HStack {
                            Image(systemName: "safari")
                            Text("Safari")
                        }
                    }
                    .onChange(of: enableSafari) { newValue in if newValue { browserNeedingHelp = "Safari"; showHelpAlert = true } }
                }
                .padding(.vertical, 4)
            } header: { Text("Browser Scrapers") }
        }
    }
    
    // ---------------------------------------------------------
    // ⚡️ HELPERS
    // ---------------------------------------------------------
    
    func checkAppExists(bundleID: String) -> Bool {
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }
    
    func toggleLaunchAtLogin(enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            print("Login Item Error: \(error)")
        }
    }
    
    func requestAccessibilityAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        if !accessEnabled {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) }
        }
        hasAccessibilityAccess = accessEnabled
    }
}

// ---------------------------------------------------------
// 🎛️ DASHBOARD SETTINGS VIEW (DRAG & DROP LAYOUT)
// ---------------------------------------------------------
struct DashboardSettingsView: View {
    @ObservedObject var dashboardManager = DashboardManager.shared
    @State private var localOrder: [NotchWidgetType] = []
    
    @AppStorage("plugin_player_enabled") var playerEnabled = true
    @AppStorage("plugin_spotify_queue_enabled") var spotifyQueueEnabled = false
    @AppStorage("plugin_spotify_playlists_enabled") var spotifyPlaylistsEnabled = false
    @AppStorage("plugin_google_calendar_enabled") var calendarEnabled = false
    @AppStorage("plugin_weather_enabled") var weatherEnabled = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Dashboard Layout")
                .font(.system(size: 28, weight: .bold))
            
            Text("Drag and drop to prioritize how widgets appear side-by-side. You can now also choose whether to display the Music Player.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            VStack(spacing: 0) {
                List {
                    ForEach(localOrder, id: \.self) { widget in
                        HStack(spacing: 12) {
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.gray)
                                .font(.system(size: 16, weight: .bold))
                                .frame(width: 20)
                            
                            Text(widget.displayName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Toggle("", isOn: binding(for: widget))
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .onMove { source, destination in
                        localOrder.move(fromOffsets: source, toOffset: destination)
                        dashboardManager.saveWidgetOrder(localOrder)
                    }
                }
                .listStyle(.plain)
            }
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            localOrder = dashboardManager.getWidgetOrder()
        }
    }
    
    private func binding(for widget: NotchWidgetType) -> Binding<Bool> {
        switch widget {
        case .player: return $playerEnabled
        case .spotifyQueue: return $spotifyQueueEnabled
        case .spotifyPlaylists: return $spotifyPlaylistsEnabled
        case .calendar: return $calendarEnabled
        case .weather: return $weatherEnabled
        }
    }
}
