import SwiftUI
import ApplicationServices
import ServiceManagement // ⚡️ NEW: Apple's native Launch at Login framework

struct SettingsView: View {
    // General Settings
    @AppStorage("showBannerOnControl") var showBannerOnControl = true
    @AppStorage("bannerDuration") var bannerDuration: Double = 3.5
    @AppStorage("showLyrics") var showLyrics = true
    
    // ⚡️ NEW: Tracks if the app is set to launch at login
    @AppStorage("launchAtLogin") var launchAtLogin = false
    
    @State private var hasAccessibilityAccess = false
    
    // Integrations
    @AppStorage("enableSpotify") var enableSpotify = false
    @AppStorage("enableChrome") var enableChrome = false
    @AppStorage("enableBrave") var enableBrave = false
    @AppStorage("enableEdge") var enableEdge = false
    @AppStorage("enableSafari") var enableSafari = false
    
    var body: some View {
        TabView {
            // GENERAL TAB
            Form {
                VStack(alignment: .leading, spacing: 15) {
                    
                    Text("App Behavior")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    // ⚡️ NEW: Launch at Login Toggle
                    Toggle(isOn: $launchAtLogin) {
                        Text("Launch at Login")
                        Text("Automatically starts WaveNotch in the background when you turn on your Mac.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .onChange(of: launchAtLogin) { newValue in
                        toggleLaunchAtLogin(enabled: newValue)
                    }
                    
                    Divider()
                    
                    // Banner Control Settings
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $showBannerOnControl) {
                            Text("Show Banner on Media Control")
                            Text("Briefly drops down the banner to say 'Resumed' or 'Paused' when you control playback.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Divider().padding(.vertical, 4)
                        
                        // Dynamic Duration Slider
                        HStack {
                            Text("Song Banner Duration:")
                            Slider(value: $bannerDuration, in: 1.0...8.0, step: 0.5)
                            Text(String(format: "%.1f sec", bannerDuration))
                                .frame(width: 50, alignment: .trailing)
                                .monospacedDigit()
                        }
                        Text("How long the banner stays visible when a new song starts.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Lyrics Setting
                    Toggle(isOn: $showLyrics) {
                        Text("Enable Live Lyrics")
                        Text("Displays synced lyrics inside the expanded player when available.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Accessibility Manager
                    Text("System Permissions")
                        .font(.headline)
                        .padding(.top, 5)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Accessibility Access")
                                .fontWeight(.medium)
                            Text("Required to simulate media keys when a browser integration isn't active.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if hasAccessibilityAccess {
                            Text("Granted")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(6)
                        } else {
                            Button("Request Access") {
                                requestAccessibilityAccess()
                            }
                        }
                    }
                }
                .padding()
            }
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
            .onAppear {
                hasAccessibilityAccess = AXIsProcessTrusted()
                // ⚡️ Syncs our toggle with the actual Mac system settings just in case
                // the user turned it off manually in System Settings > Login Items
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
            
            // INTEGRATIONS TAB
            Form {
                VStack(alignment: .leading, spacing: 15) {
                    Text("Select which apps WaveNotch is allowed to read and control. macOS will ask for your permission the first time you enable each one.")
                        .foregroundColor(.secondary)
                        .padding(.bottom, 5)
                    
                    Toggle(isOn: $enableSpotify) {
                        Text("Spotify Native App")
                        Text("Allows WaveNotch to display and control your Spotify music.").font(.caption).foregroundColor(.secondary)
                    }
                    .onChange(of: enableSpotify) { newValue in
                        if newValue { triggerPermission(for: "Spotify") }
                    }
                    
                    Divider()
                    
                    Toggle(isOn: $enableChrome) {
                        Text("Google Chrome")
                        Text("Allows WaveNotch to read media playing in Chrome tabs.").font(.caption).foregroundColor(.secondary)
                    }
                    .onChange(of: enableChrome) { newValue in
                        if newValue { triggerPermission(for: "Google Chrome") }
                    }
                    
                    Divider()
                    
                    Toggle(isOn: $enableBrave) {
                        Text("Brave Browser")
                        Text("Allows WaveNotch to read media playing in Brave tabs.").font(.caption).foregroundColor(.secondary)
                    }
                    .onChange(of: enableBrave) { newValue in
                        if newValue { triggerPermission(for: "Brave Browser") }
                    }
                    
                    Divider()
                    
                    Toggle(isOn: $enableSafari) {
                        Text("Safari")
                        Text("Allows WaveNotch to read media playing in Safari tabs.").font(.caption).foregroundColor(.secondary)
                    }
                    .onChange(of: enableSafari) { newValue in
                        if newValue { triggerPermission(for: "Safari") }
                    }
                }
                .padding()
            }
            .tabItem {
                Label("Integrations", systemImage: "puzzlepiece.extension")
            }
        }
        .frame(width: 480, height: 540) // Made the window slightly taller to fit everything cleanly!
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasAccessibilityAccess = AXIsProcessTrusted()
        }
    }
    
    // ⚡️ NEW: The function that safely tells macOS to launch the app at login
    func toggleLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update Launch at Login status: \(error)")
            // If it fails, revert the toggle back to the actual system state
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
    
    func triggerPermission(for appName: String) {
        let script = "tell application \"\(appName)\" to running"
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
        }
    }
    
    func requestAccessibilityAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
        
        hasAccessibilityAccess = accessEnabled
    }
}
