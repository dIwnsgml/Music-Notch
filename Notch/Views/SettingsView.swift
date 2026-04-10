import SwiftUI
import ApplicationServices
import ServiceManagement
import AppKit

struct SettingsView: View {
    // General Settings
    @AppStorage("showBannerOnControl") var showBannerOnControl = true
    @AppStorage("bannerDuration") var bannerDuration: Double = 3.5
    @AppStorage("showLyrics") var showLyrics = true
    @AppStorage("launchAtLogin") var launchAtLogin = false
    
    @State private var hasAccessibilityAccess = false
    
    // Integrations
    @AppStorage("enableSpotify") var enableSpotify = false
    @AppStorage("enableChrome") var enableChrome = false
    @AppStorage("enableBrave") var enableBrave = false
    @AppStorage("enableEdge") var enableEdge = false
    @AppStorage("enableSafari") var enableSafari = false
    
    // Installed Checkers
    @State private var isSpotifyInstalled = false
    @State private var isChromeInstalled = false
    @State private var isBraveInstalled = false
    @State private var isEdgeInstalled = false
    @State private var isSafariInstalled = true
    
    // ⚡️ NEW: Help Alert State
    @State private var browserNeedingHelp: String? = nil
    @State private var showHelpAlert = false

    var body: some View {
        TabView {
            // ---------------------------------------------------------
            // GENERAL TAB (Unchanged)
            // ---------------------------------------------------------
            Form {
                VStack(alignment: .leading, spacing: 15) {
                    Text("App Behavior").font(.headline).padding(.bottom, 5)
                    
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { newValue in toggleLaunchAtLogin(enabled: newValue) }
                    Text("Automatically starts WaveNotch in the background when you turn on your Mac.").font(.caption).foregroundColor(.secondary)
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Show Banner on Media Control", isOn: $showBannerOnControl)
                        Text("Briefly drops down the banner to say 'Resumed' or 'Paused' when you control playback.").font(.caption).foregroundColor(.secondary)
                        Divider().padding(.vertical, 4)
                        HStack {
                            Text("Song Banner Duration:")
                            Slider(value: $bannerDuration, in: 1.0...8.0, step: 0.5)
                            Text(String(format: "%.1f sec", bannerDuration)).frame(width: 50, alignment: .trailing).monospacedDigit()
                        }
                    }
                    Divider()
                    
                    Toggle("Enable Live Lyrics", isOn: $showLyrics)
                    Text("Displays synced lyrics inside the expanded player when available.").font(.caption).foregroundColor(.secondary)
                    Divider()
                    
                    Text("System Permissions").font(.headline).padding(.top, 5)
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Accessibility Access").fontWeight(.medium)
                            Text("Required to simulate media keys.").font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        if hasAccessibilityAccess {
                            Text("Granted").font(.subheadline).fontWeight(.bold).foregroundColor(.green).padding(.horizontal, 10).padding(.vertical, 4).background(Color.green.opacity(0.1)).cornerRadius(6)
                        } else {
                            Button("Request Access") { requestAccessibilityAccess() }
                        }
                    }
                }
                .padding()
            }
            .tabItem { Label("General", systemImage: "gearshape") }
            .onAppear {
                hasAccessibilityAccess = AXIsProcessTrusted()
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
            
            // ---------------------------------------------------------
            // INTEGRATIONS TAB (With Test & Guide UX)
            // ---------------------------------------------------------
            Form {
                VStack(alignment: .leading, spacing: 15) {
                    Text("Select which apps WaveNotch is allowed to read and control.")
                        .foregroundColor(.secondary)
                        .padding(.bottom, 5)
                    
                    if isSpotifyInstalled {
                        Toggle(isOn: $enableSpotify) {
                            Text("Spotify Native App")
                            Text("Allows WaveNotch to display and control your Spotify music.").font(.caption).foregroundColor(.secondary)
                        }
                        .onChange(of: enableSpotify) { newValue in
                            if newValue { triggerPermission(for: "Spotify") }
                        }
                        Divider()
                    }
                    
                    if isChromeInstalled {
                        browserToggle(title: "Google Chrome", isOn: $enableChrome, internalName: "Google Chrome")
                        Divider()
                    }
                    
                    if isBraveInstalled {
                        browserToggle(title: "Brave Browser", isOn: $enableBrave, internalName: "Brave Browser")
                        Divider()
                    }
                    
                    if isEdgeInstalled {
                        browserToggle(title: "Microsoft Edge", isOn: $enableEdge, internalName: "Microsoft Edge")
                        Divider()
                    }
                    
                    if isSafariInstalled {
                        browserToggle(title: "Safari", isOn: $enableSafari, internalName: "Safari")
                    }
                    
                    if !isSpotifyInstalled && !isChromeInstalled && !isBraveInstalled && !isEdgeInstalled {
                        Text("No supported third-party browsers or Spotify detected.")
                            .font(.callout)
                            .foregroundColor(.orange)
                            .padding(.top, 10)
                    }
                }
                .padding()
            }
            .tabItem { Label("Integrations", systemImage: "puzzlepiece.extension") }
            .onAppear {
                isSpotifyInstalled = checkAppExists(bundleID: "com.spotify.client")
                isChromeInstalled = checkAppExists(bundleID: "com.google.Chrome")
                isBraveInstalled = checkAppExists(bundleID: "com.brave.Browser")
                isEdgeInstalled = checkAppExists(bundleID: "com.microsoft.edgemac")
            }
            // ⚡️ THE SMART HELP ALERT
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
        .frame(width: 480, height: 540)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasAccessibilityAccess = AXIsProcessTrusted()
        }
    }
    
    // ⚡️ THE SMART BROWSER ROW COMPONENT
    @ViewBuilder
    func browserToggle(title: String, isOn: Binding<Bool>, internalName: String) -> some View {
        HStack {
            Toggle(isOn: isOn) {
                Text(title)
                Text("Allows WaveNotch to read media playing in \(title) tabs.").font(.caption).foregroundColor(.secondary)
            }
            .onChange(of: isOn.wrappedValue) { newValue in
                if newValue {
                    // First, trigger standard macOS permission
                    triggerPermission(for: internalName)
                    
                    // Second, test if JavaScript injection is actually allowed
                    if !testJavaScriptAccess(for: internalName) {
                        // If it fails, turn the toggle back off and show the instructions!
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            isOn.wrappedValue = false
                            browserNeedingHelp = title
                            showHelpAlert = true
                        }
                    }
                }
            }
            
            Spacer()
            
            // Manual Help Button just in case they need the instructions again
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
    
    // ⚡️ THE DIAGNOSTIC ENGINE
    // This secretly injects "1+1" into the browser. If the browser blocks it, we know the user hasn't flipped the security switch!
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
            // If the browser is completely closed, it might return FAIL, but that's okay,
            // the alert will just remind them to open it and check the setting!
            if result == "FAIL" || error != nil {
                return false
            }
            return true
        }
        return false
    }
    
    // Helpers
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
