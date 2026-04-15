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
    case shortcuts = "Shortcuts" // ⚡️ NEW TAB
    case integrations = "Integrations"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .lyrics: return "text.quote"
        case .shortcuts: return "keyboard" // ⚡️ NEW ICON
        case .integrations: return "puzzlepiece.extension"
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
                
                Form {
                    switch selectedTab {
                    case .general: generalContent
                    case .lyrics: lyricsContent
                    case .shortcuts: shortcutsContent
                    case .integrations: integrationsContent
                    }
                }
                .formStyle(.grouped)
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
                        Text("Calendar Permission")
                        Spacer()
                        if calendarManager.hasAccess {
                            Text("Granted")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(6)
                        } else {
                            Button("Request Access") { calendarManager.requestAccess() }
                        }
                    }
                }
            } header: {
                Text("Productivity")
            } footer: {
                Text("Displays your upcoming events next to the player.")
            }
            
            Section {
                if isAppleMusicInstalled {
                    Toggle("Apple Music App", isOn: $enableAppleMusic)
                        .onChange(of: enableAppleMusic) { newValue in if newValue { triggerPermission(for: "Music") } }
                }
                if isSpotifyInstalled {
                    Toggle("Spotify Native App", isOn: $enableSpotify)
                        .onChange(of: enableSpotify) { newValue in if newValue { triggerPermission(for: "Spotify") } }
                }
            } header: { Text("Native Players") }
            
            Section {
                if isSafariInstalled { browserToggle(title: "Safari", isOn: $enableSafari, internalName: "Safari") }
                if isChromeInstalled { browserToggle(title: "Google Chrome", isOn: $enableChrome, internalName: "Google Chrome") }
                if isBraveInstalled { browserToggle(title: "Brave Browser", isOn: $enableBrave, internalName: "Brave Browser") }
                if isEdgeInstalled { browserToggle(title: "Microsoft Edge", isOn: $enableEdge, internalName: "Microsoft Edge") }
            } header: { Text("Web Browsers") }
        }
    }
    
    
    // ---------------------------------------------------------
    // ⚡️ HELPER METHODS
    // ---------------------------------------------------------
    @ViewBuilder
    func browserToggle(title: String, isOn: Binding<Bool>, internalName: String) -> some View {
        HStack {
            Toggle(isOn: isOn) {
                Text(title)
                Text("Allows WaveNotch to read media playing in \(title) tabs.").font(.caption).foregroundColor(.secondary)
            }
            .onChange(of: isOn.wrappedValue) { newValue in
                if newValue {
                    triggerPermission(for: internalName)
                    
                    if !testJavaScriptAccess(for: internalName) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            isOn.wrappedValue = false
                            browserNeedingHelp = title
                            showHelpAlert = true
                        }
                    }
                }
            }
            
            Spacer()
            
            Button(action: {
                browserNeedingHelp = title
                showHelpAlert = true
            }) {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            .help("Setup Instructions")
        }
    }
    
    func testJavaScriptAccess(for browser: String) -> Bool {
        let scriptSource: String
        if browser == "Safari" {
            scriptSource = """
            tell application "Safari"
                try
                    do JavaScript "1+1" in document 1
                    return "SUCCESS"
                on error
                    return "FAIL"
                end try
            end tell
            """
        } else {
            scriptSource = """
            tell application "\(browser)"
                try
                    execute active tab of window 1 javascript "1+1"
                    return "SUCCESS"
                on error
                    return "FAIL"
                end try
            end tell
            """
        }
        var error: NSDictionary?
        if let script = NSAppleScript(source: scriptSource) {
            let result = script.executeAndReturnError(&error).stringValue
            if result == "FAIL" || error != nil { return false }
            return true
        }
        return false
    }
    
    func checkAppExists(bundleID: String) -> Bool {
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }
    
    func toggleLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else { try SMAppService.mainApp.unregister() }
        } catch { launchAtLogin = SMAppService.mainApp.status == .enabled }
    }
    
    func triggerPermission(for appName: String) {
        let script = "tell application \"\(appName)\" to running"
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) { appleScript.executeAndReturnError(&error) }
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
