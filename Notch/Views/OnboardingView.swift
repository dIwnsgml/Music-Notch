import SwiftUI
import ApplicationServices

struct OnboardingView: View {
    private let totalPages = 6

    @State private var currentPage = 0
    @State private var hasAccessibilityAccess = AXIsProcessTrusted()

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("enableAnalytics") private var enableAnalytics = true

    @AppStorage("themeBackgroundType") private var themeBackgroundType = "preset"
    @AppStorage("themePresetID") private var themePresetID = ThemePreset.defaultID
    @AppStorage("themeBackgroundOpacity") private var themeBackgroundOpacity = 1.0
    @AppStorage("themeGlassyWidgets") private var themeGlassyWidgets = true

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
                case 4: gesturesPage
                case 5: finishPage
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
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasAccessibilityAccess = AXIsProcessTrusted()
        }
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
            subtitle: "Set up music controls, live lyrics, widgets, and your notch theme in a few steps."
        ) {
            HStack(spacing: 22) {
                onboardingNotchPreview

                VStack(alignment: .leading, spacing: 14) {
                    OnboardingFeatureRow(icon: "music.note", color: .orange, title: "Music-aware notch", desc: "Shows what is playing and gives you quick playback controls.")
                    OnboardingFeatureRow(icon: "text.quote", color: .blue, title: "Live lyrics", desc: "Displays synced lyrics in the expanded player and menu-bar banner.")
                    OnboardingFeatureRow(icon: "square.grid.2x2", color: .purple, title: "Useful plugins", desc: "Add weather, timers, clipboard history, files, tasks, queues, and more.")
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

    private var gesturesPage: some View {
        OnboardingPage(
            symbol: "hand.draw.fill",
            symbolColor: .purple,
            title: "Learn the quick controls",
            subtitle: "These defaults make the notch useful without opening Settings every time."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                OnboardingFeatureRow(icon: "hand.draw.fill", color: .purple, title: "Swipe or scroll to skip", desc: "Hover over the notch and scroll left or right to move between tracks.")
                OnboardingFeatureRow(icon: "cursorarrow.click.2", color: .blue, title: "Double click to open", desc: "Double click the expanded player to open the active media app or browser.")
                OnboardingFeatureRow(icon: "keyboard", color: .orange, title: "Hide instantly", desc: "Use Control + Command + H to hide or show WaveNotch globally.")
            }
            .padding(20)
            .frame(maxWidth: 560, alignment: .leading)
            .background(panelBackground)
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
                        Text("Media apps and plugin layout can be changed anytime.")
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
    }

    private func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        hasAccessibilityAccess = AXIsProcessTrusted()
    }

    private func finishOnboarding() {
        hasCompletedOnboarding = true
        OnboardingWindowManager.shared.close()
    }
}

private struct OnboardingPage<Content: View>: View {
    let symbol: String
    let symbolColor: Color
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(symbolColor.opacity(0.16))
                        .frame(width: 72, height: 72)
                    Image(systemName: symbol)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(symbolColor)
                }

                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 30, weight: .black))
                        .multilineTextAlignment(.center)

                    Text(subtitle)
                        .font(.system(size: 14, weight: .semibold))
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
        .padding(.top, 34)
        .padding(.bottom, 18)
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
