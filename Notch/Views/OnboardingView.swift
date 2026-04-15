import SwiftUI
import ApplicationServices
import Combine

struct OnboardingView: View {
    @State private var currentPage = 0
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    @AppStorage("enableAnalytics") var enableAnalytics = true
    
    @State private var hasAccessibilityAccess = AXIsProcessTrusted()
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    // ⚡️ NEW: App Storage for Integrations
    @AppStorage("enableAppleMusic") var enableAppleMusic = false
    @AppStorage("enableSpotify") var enableSpotify = false
    @AppStorage("enableChrome") var enableChrome = false
    @AppStorage("enableBrave") var enableBrave = false
    @AppStorage("enableEdge") var enableEdge = false
    @AppStorage("enableSafari") var enableSafari = false
    
    var body: some View {
        VStack(spacing: 0) {
            
            ZStack {
                switch currentPage {
                case 0: welcomePage.transition(.opacity)
                case 1: permissionsPage.transition(.opacity)
                case 2: integrationsPage.transition(.opacity) // ⚡️ NEW PAGE
                case 3: gesturesPage.transition(.opacity)
                case 4: finishPage.transition(.opacity)
                default: EmptyView()
                }
            }
            .id(currentPage)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            // Bottom Navigation Bar
            HStack {
                // Page Indicators
                HStack(spacing: 8) {
                    ForEach(0..<5) { index in // ⚡️ Bumped to 5
                        Circle()
                            .fill(currentPage == index ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.spring(), value: currentPage)
                    }
                }
                
                Spacer()
                
                if currentPage < 4 { // ⚡️ Bumped to 4
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) { currentPage += 1 }
                    }) {
                        Text(currentPage == 1 && !hasAccessibilityAccess ? "Skip for now" : "Next")
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(currentPage == 1 && !hasAccessibilityAccess ? .gray : .accentColor)
                } else {
                    Button(action: { finishOnboarding() }) {
                        Text("Get Started")
                            .font(.system(size: 13, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(24)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 500, height: 420)
        .onReceive(timer) { _ in
            if currentPage == 1 {
                let isTrusted = AXIsProcessTrusted()
                
                if !hasAccessibilityAccess && isTrusted {
                    withAnimation { hasAccessibilityAccess = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation(.easeInOut(duration: 0.3)) { currentPage = 2 }
                    }
                } else if !isTrusted {
                    hasAccessibilityAccess = false
                }
            }
        }
    }
    
    // ---------------------------------------------------------
    // 📖 THE PAGES
    // ---------------------------------------------------------
    
    private var welcomePage: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color.orange, Color.red], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.orange.opacity(0.4), radius: 12, y: 6)
                
                Image(systemName: "music.note")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.bottom, 8)
            
            Text("Welcome to WaveNotch")
                .font(.system(size: 28, weight: .bold))
            
            Text("The Dynamic Island your Mac always deserved.\nControl your music, view your lyrics, and manage your day.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private var permissionsPage: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
                .padding(.bottom, 8)
            
            Text("We need a tiny favor.")
                .font(.system(size: 24, weight: .bold))
            
            Text("To seamlessly read what song is playing and simulate media key presses (like skipping a track), WaveNotch requires Accessibility access.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            VStack(spacing: 12) {
                if hasAccessibilityAccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                        Text("Access Granted!").fontWeight(.semibold)
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                } else {
                    Button(action: { requestAccess() }) {
                        Text("Open System Settings")
                            .fontWeight(.semibold)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    
                    Text("1. Click the button above\n2. Turn on the toggle next to WaveNotch")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 10)
        }
    }
    
    // ⚡️ NEW: Integrations Page (Layout Fixed!)
    private var integrationsPage: some View {
        VStack(spacing: 16) {
            Image(systemName: "puzzlepiece.extension.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)
                .padding(.bottom, 4)
            
            Text("Connect Your Media")
                .font(.system(size: 24, weight: .bold))
            
            Text("Which apps do you use to listen to music? WaveNotch will watch these tabs and applications to track your current song.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 8)
            
            // ⚡️ THE FIX: Top alignment and fixed spacing
            HStack(alignment: .top, spacing: 40) {
                
                // LEFT COLUMN
                VStack(alignment: .leading, spacing: 14) {
                    Text("NATIVE PLAYERS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                    
                    Toggle("Spotify", isOn: $enableSpotify)
                    Toggle("Apple Music", isOn: $enableAppleMusic)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading) // ⚡️ Forces exactly 50% width
                
                // RIGHT COLUMN
                VStack(alignment: .leading, spacing: 14) {
                    Text("WEB BROWSERS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.gray)
                    
                    Toggle("Google Chrome", isOn: $enableChrome)
                    Toggle("Brave Browser", isOn: $enableBrave)
                    Toggle("Safari", isOn: $enableSafari)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading) // ⚡️ Forces exactly 50% width
                
            }
            .toggleStyle(.switch)
            .padding(.horizontal, 30)
            .padding(.vertical, 20)
            .background(Color.black.opacity(0.15)) // Slightly darker for better contrast
            .cornerRadius(12)
            .padding(.horizontal, 40) // Adds breathing room around the outside of the box
        }
    }
    
    private var gesturesPage: some View {
        VStack(spacing: 24) {
            Text("Pro Tips & Gestures")
                .font(.system(size: 24, weight: .bold))
            
            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(icon: "hand.draw.fill", color: .purple, title: "Swipe to Skip", desc: "Hover over the notch and scroll left or right on your mouse/trackpad to skip tracks.")
                FeatureRow(icon: "cursorarrow.click.2", color: .blue, title: "Double Click", desc: "Double click the expanded player to instantly open Spotify, Apple Music, or your Browser.")
                FeatureRow(icon: "keyboard", color: .orange, title: "The Boss Key", desc: "Press ^⌘H to completely hide or show the notch from anywhere on your Mac.")
            }
            .padding(.horizontal, 40)
        }
    }
    
    private var finishPage: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundColor(.yellow)
                .padding(.bottom, 8)
            
            Text("You're all set!")
                .font(.system(size: 24, weight: .bold))
            
            Text("WaveNotch is running quietly in your menu bar.\nPlay a song in Spotify, Music, or your browser to see it in action.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Toggle("Share anonymous crash & usage data to help us improve", isOn: $enableAnalytics)
                .font(.system(size: 12))
                .padding(.horizontal, 40)
                .padding(.top, 20)
        }
    }
    
    // ---------------------------------------------------------
    // ⚡️ HELPERS
    // ---------------------------------------------------------
    private func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
    
    private func finishOnboarding() {
        hasCompletedOnboarding = true
        OnboardingWindowManager.shared.close()
        // ⚡️ Removed the Settings open here since they just set everything up!
    }
}

struct FeatureRow: View {
    var icon: String
    var color: Color
    var title: String
    var desc: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 14, weight: .bold))
                Text(desc).font(.system(size: 13)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
