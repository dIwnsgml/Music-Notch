import SwiftUI
import ApplicationServices // ⚡️ NEW: Required to check Accessibility permissions

struct SettingsView: View {
    // General Settings
    @AppStorage("showBannerOnControl") var showBannerOnControl = true
    
    // ⚡️ NEW: Tracks if the Mac has granted us keystroke permissions
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
                    
                    // ⚡️ NEW: Accessibility Permission Manager
                    Text("System Permissions")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Accessibility Access")
                                .fontWeight(.medium)
                            Text("Required for WaveNotch to simulate media keys (Play, Pause, Skip) when a browser integration isn't active.")
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
                    
                    Divider()
                    
                    Text("App Behavior")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    Toggle(isOn: $showBannerOnControl) {
                        Text("Show Banner on Media Control")
                        Text("Automatically drops down the WaveNotch banner when you play, pause, or skip tracks.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
            .onAppear {
                // Check status every time they open the General tab
                hasAccessibilityAccess = AXIsProcessTrusted()
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
        .frame(width: 480, height: 450)
        // ⚡️ NEW: Watch for when the user clicks back into the app from System Settings
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasAccessibilityAccess = AXIsProcessTrusted()
        }
    }
    
    // Fires a harmless script to trigger the macOS permission popup right when they click
    func triggerPermission(for appName: String) {
        let script = "tell application \"\(appName)\" to running"
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
        }
    }
    
    // ⚡️ NEW: The function that handles the Accessibility request
    func requestAccessibilityAccess() {
        // This dictionary tells macOS to throw the native popup if permission is missing
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        // If they previously clicked "Deny", macOS will stubbornly refuse to show the popup again.
        // We catch that here and force-open their Mac's System Settings directly to the right page!
        if !accessEnabled {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
        
        hasAccessibilityAccess = accessEnabled
    }
}
