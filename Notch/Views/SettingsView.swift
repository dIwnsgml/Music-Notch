import SwiftUI
import ApplicationServices
import ServiceManagement
import AppKit

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case lyrics = "Lyrics & Banner"
    case integrations = "Integrations"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .lyrics: return "text.quote"
        case .integrations: return "puzzlepiece.extension"
        }
    }
}

struct SettingsView: View {
    @AppStorage("lastSettingsTab") var selectedTab: SettingsTab = .general
    
    // ⚡️ CUSTOM SIDEBAR STATE
    @State private var showSidebar = true
    
    // ⚡️ GENERAL
    @AppStorage("launchAtLogin") var launchAtLogin = false
    @AppStorage("showGlowEffect") var showGlowEffect = true
    @AppStorage("invertSwipeDirection") var invertSwipeDirection = true
    
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
    
    var body: some View {
        // ⚡️ THE FIX: NavigationStack triggers the gorgeous, native macOS glass title bar!
        NavigationStack {
            HStack(spacing: 0) {
                // CUSTOM SIDEBAR
                if showSidebar {
                    List(SettingsTab.allCases, selection: $selectedTab) { tab in
                        Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                    }
                    .listStyle(.sidebar)
                    .frame(width: 180)
                    .transition(.move(edge: .leading))
                    
                    Divider()
                }
                
                // CONTENT FORM
                Form {
                    switch selectedTab {
                    case .general: generalContent
                    case .lyrics: lyricsContent
                    case .integrations: integrationsContent
                    }
                }
                .formStyle(.grouped)
            }
            .navigationTitle(selectedTab.rawValue) // Sets the native title in the glass bar
            .toolbar {
                // ⚡️ THE FIX: Anchors the button natively to the top left so it never jumps!
                ToolbarItem(placement: .navigation) {
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showSidebar.toggle()
                        }
                    }) {
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
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasAccessibilityAccess = AXIsProcessTrusted()
        }
        .alert(isPresented: $showHelpAlert) {
            let browser = browserNeedingHelp ?? "Browser"
            let isSafari = browser == "Safari"
            return Alert(
                title: Text("Action Required for \(browser)"),
                message: Text(isSafari ?
                              "1. Open Safari\n2. Click 'Safari' in the top menu bar -> 'Settings'\n3. Go to 'Advanced' and check 'Show Develop menu'\n4. Click 'Develop' in the top menu bar\n5. Check 'Allow JavaScript from Apple Events'"
                              :
                                "1. Open \(browser)\n2. Click 'View' in the top Mac menu bar\n3. Hover over 'Developer'\n4. Click 'Allow JavaScript from Apple Events'"),
                dismissButton: .default(Text("I've done this!"))
            )
        }
    }
    
    // ---------------------------------------------------------
    // ⚙️ GENERAL TAB
    // ---------------------------------------------------------
    private var generalContent: some View {
        Group {
            Section {
                HStack {
                    Text("Accessibility Access")
                    Spacer()
                    if hasAccessibilityAccess {
                        Text("Granted")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(6)
                    } else {
                        Button("Request Access") { requestAccessibilityAccess() }
                    }
                }
            } header: {
                Text("System Permissions")
            } footer: {
                Text("Required to read track data and enable trackpad swipe gestures.")
            }
            
            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in toggleLaunchAtLogin(enabled: newValue) }
                
                Toggle("Show Cinematic Glow on Song Change", isOn: $showGlowEffect)
                
                Toggle("Invert Swipe Direction", isOn: $invertSwipeDirection)
            } header: {
                Text("App Behavior")
            } footer: {
                Text("Changes the direction for skipping tracks with your trackpad or mouse.")
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
                if isAppleMusicInstalled {
                    Toggle("Apple Music App", isOn: $enableAppleMusic)
                        .onChange(of: enableAppleMusic) { newValue in
                            if newValue { triggerPermission(for: "Music") }
                        }
                }
                if isSpotifyInstalled {
                    Toggle("Spotify Native App", isOn: $enableSpotify)
                        .onChange(of: enableSpotify) { newValue in
                            if newValue { triggerPermission(for: "Spotify") }
                        }
                }
            } header: {
                Text("Native Players")
            } footer: {
                Text("Select which apps WaveNotch is allowed to control.")
            }
            
            Section {
                if isSafariInstalled { browserToggle(title: "Safari", isOn: $enableSafari, internalName: "Safari") }
                if isChromeInstalled { browserToggle(title: "Google Chrome", isOn: $enableChrome, internalName: "Google Chrome") }
                if isBraveInstalled { browserToggle(title: "Brave Browser", isOn: $enableBrave, internalName: "Brave Browser") }
                if isEdgeInstalled { browserToggle(title: "Microsoft Edge", isOn: $enableEdge, internalName: "Microsoft Edge") }
                
                if !isSpotifyInstalled && !isChromeInstalled && !isBraveInstalled && !isEdgeInstalled && !isSafariInstalled {
                    Text("No supported third-party browsers detected.")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Web Browsers")
            } footer: {
                Text("Required to read media playing in browser tabs.")
            }
        }
    }
    
    // ---------------------------------------------------------
    // ⚡️ HELPER METHODS
    // ---------------------------------------------------------
    @ViewBuilder
    func browserToggle(title: String, isOn: Binding<Bool>, internalName: String) -> some View {
        HStack {
            Toggle(title, isOn: isOn)
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
