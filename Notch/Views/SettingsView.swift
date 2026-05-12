import SwiftUI
import PostHog
import ApplicationServices
import ServiceManagement
import AppKit
import KeyboardShortcuts // ⚡️ Import the package
import Sparkle
import UniformTypeIdentifiers

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case theme = "Theme" // ⚡️ NEW: Custom backgrounds
    case lyrics = "Lyrics & Banner"
    case layout = "Layout" // ⚡️ NEW: Layout Editor
    case shortcuts = "Shortcuts"
    case integrations = "Integrations"
    case plugins = "Plugins"

    var id: String { self.rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .theme: return "paintbrush"
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

    // ⚡️ THEME
    @AppStorage("themeBackgroundType") var themeBackgroundType: String = "preset"
    @AppStorage("themePresetID") var themePresetID: String = ThemePreset.defaultID
    @AppStorage("themeBackgroundColorHex") var themeBackgroundColorHex: String = "000000"
    @AppStorage("themeBackgroundImagePath") var themeBackgroundImagePath: String = ""
    @AppStorage("themeBackgroundOpacity") var themeBackgroundOpacity: Double = 1.0
    @AppStorage("themeBackgroundBlur") var themeBackgroundBlur: Double = 0.0
    @AppStorage("themeGlassyWidgets") var themeGlassyWidgets: Bool = true

    // ⚡️ LYRICS & BANNER
    @AppStorage("showBannerOnControl") var showBannerOnControl = true
    @AppStorage("bannerDuration") var bannerDuration: Double = 3.5
    @AppStorage("showLyrics") var showLyrics = true
    @AppStorage("showBannerLyrics") var showBannerLyrics = true
    @AppStorage("visibleLyricLines") var visibleLyricLines = 3
    @AppStorage("lyricDimming") var lyricDimming: Double = 0.3
    @AppStorage("lyricBlurAmount") var lyricBlurAmount: Double = 0.4
    @AppStorage("globalLyricOffset") var globalLyricOffset: Double = 0.0
    @AppStorage("plugin_pomodoro_timer_installed") var pomodoroInstalled = false
    @AppStorage("pomodoro_show_notch_timer") var showPomodoroNotchTimer = true
    @AppStorage("pomodoro_show_time_text") var showPomodoroTimeText = true
    @AppStorage("pomodoro_show_timer_banner") var showPomodoroTimerBanner = false

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
                    } else if selectedTab == .theme {
                        themeContent
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
        .frame(width: 820, height: 680)
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
                KeyboardShortcuts.Recorder("Make Current Song Lyrics Earlier (+0.5s)", name: .increaseOffset)
                KeyboardShortcuts.Recorder("Make Current Song Lyrics Later (-0.5s)", name: .decreaseOffset)
            } header: {
                Text("Per-Song Lyric Synchronization")
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
    // 🎨 THEME TAB
    // ---------------------------------------------------------
    private var themeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                themeHero
                themeAdjustmentsPanel
                themePresetSection(.dynamic)
                themePhotosSection
                themePresetSection(.landscape)
                themePresetSection(.cityscape)
                themePresetSection(.minimal)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 26)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var selectedTheme: ThemePreset {
        ThemePreset.preset(id: themePresetID)
    }

    private var currentThemeName: String {
        switch themeBackgroundType {
        case "image":
            return "Custom Photo"
        case "color":
            return "Solid Color"
        default:
            return selectedTheme.name
        }
    }

    private var currentThemeDescription: String {
        switch themeBackgroundType {
        case "image":
            return themeBackgroundImagePath.isEmpty ? "Choose a photo to use as the notch background." : URL(fileURLWithPath: themeBackgroundImagePath).lastPathComponent
        case "color":
            return "Uses a single custom color across the notch."
        default:
            return selectedTheme.subtitle
        }
    }

    private var themeHero: some View {
        HStack(alignment: .top, spacing: 20) {
            ThemePreviewThumbnail(
                backgroundType: themeBackgroundType,
                presetID: themePresetID,
                colorHex: themeBackgroundColorHex,
                imagePath: themeBackgroundImagePath,
                opacity: themeBackgroundOpacity,
                blur: themeBackgroundBlur,
                cornerRadius: 14
            )
            .frame(width: 300, height: 180)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(currentThemeName)
                            .font(.system(size: 24, weight: .bold))
                            .lineLimit(1)

                        Text(currentThemeDescription)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .frame(height: 38, alignment: .topLeading)
                    }

                    Spacer(minLength: 12)

                    Picker("Mode", selection: $themeBackgroundType) {
                        Text("Theme").tag("preset")
                        Text("Color").tag("color")
                        Text("Photo").tag("image")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }

                Divider()

                HStack(spacing: 12) {
                    Label(themeModeLabel, systemImage: themeModeIcon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.secondary)

                    Spacer()

                    Button("Reset Theme") {
                        applyPreset(ThemePreset.preset(id: ThemePreset.defaultID))
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: 180, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .frame(height: 180)
    }

    private var themeModeLabel: String {
        switch themeBackgroundType {
        case "image": return "Photo Background"
        case "color": return "Solid Color"
        default: return "Default Theme"
        }
    }

    private var themeModeIcon: String {
        switch themeBackgroundType {
        case "image": return "photo"
        case "color": return "paintpalette.fill"
        default: return "sparkles"
        }
    }

    private var themeAdjustmentsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Label("Background Adjustments", systemImage: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .bold))

                Spacer()

                Toggle("Glassy Widgets", isOn: $themeGlassyWidgets)
                    .font(.system(size: 12, weight: .semibold))
            }

            HStack(alignment: .top, spacing: 18) {
                adjustmentSlider(
                    title: "Opacity",
                    valueText: "\(Int(themeBackgroundOpacity * 100))%",
                    rangeLabelStart: "0%",
                    rangeLabelEnd: "100%",
                    value: $themeBackgroundOpacity,
                    range: 0.0...1.0,
                    step: 0.05
                )

                if themeBackgroundType == "image" {
                    adjustmentSlider(
                        title: "Photo Blur",
                        valueText: "\(Int(themeBackgroundBlur))",
                        rangeLabelStart: "0",
                        rangeLabelEnd: "40",
                        value: $themeBackgroundBlur,
                        range: 0.0...40.0,
                        step: 1.0
                    )
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Photo Blur")
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Text("Photo only")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                        }

                        Text("Blur appears when Photo mode is selected.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(height: 24, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            HStack(spacing: 10) {
                Picker("Background Type", selection: $themeBackgroundType) {
                    Text("Theme").tag("preset")
                    Text("Color").tag("color")
                    Text("Photo").tag("image")
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 240)

                if themeBackgroundType == "color" {
                    ColorPicker("Color", selection: Binding(
                        get: { Color(hex: themeBackgroundColorHex) ?? .black },
                        set: { themeBackgroundColorHex = $0.toHex() }
                    ))
                    .labelsHidden()
                    .frame(width: 44)
                }

                if themeBackgroundType == "image" {
                    Button("Choose Photo...") {
                        chooseThemeImage()
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func adjustmentSlider(
        title: String,
        valueText: String,
        rangeLabelStart: String,
        rangeLabelEnd: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(valueText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                Text(rangeLabelStart)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 34, alignment: .leading)
                Slider(value: value, in: range, step: step)
                    .labelsHidden()
                Text(rangeLabelEnd)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func themePresetSection(_ category: ThemePresetCategory) -> some View {
        let presets = ThemePreset.presets(in: category)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(category.rawValue)
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                Text("Show All (\(presets.count))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 18) {
                    ForEach(presets) { preset in
                        presetCard(preset)
                    }
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 1)
            }
        }
    }

    private func presetCard(_ preset: ThemePreset) -> some View {
        let isSelected = themeBackgroundType == "preset" && themePresetID == preset.id

        return Button {
            applyPreset(preset)
        } label: {
            VStack(alignment: .center, spacing: 8) {
                ZStack(alignment: .bottomLeading) {
                    ThemePresetBackground(presetID: preset.id)
                        .frame(width: 154, height: 86)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.55), radius: 4, y: 1)
                            .padding(8)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.10), lineWidth: isSelected ? 3 : 1)
                )

                Text(preset.name)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(width: 154)
            }
        }
        .buttonStyle(.plain)
    }

    private var themePhotosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Photos")
                .font(.system(size: 18, weight: .bold))

            HStack(alignment: .top, spacing: 18) {
                Button {
                    chooseThemeImage()
                } label: {
                    VStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.07))
                            .frame(width: 154, height: 86)
                            .overlay(
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(.secondary)
                            )

                        Text("Add Photo...")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                            .frame(width: 154)
                    }
                }
                .buttonStyle(.plain)

                if !themeBackgroundImagePath.isEmpty {
                    Button {
                        themeBackgroundType = "image"
                    } label: {
                        VStack(spacing: 8) {
                            ThemePreviewThumbnail(
                                backgroundType: "image",
                                presetID: themePresetID,
                                colorHex: themeBackgroundColorHex,
                                imagePath: themeBackgroundImagePath,
                                opacity: themeBackgroundOpacity,
                                blur: themeBackgroundBlur,
                                cornerRadius: 8
                            )
                            .frame(width: 154, height: 86)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(themeBackgroundType == "image" ? Color.accentColor : Color.white.opacity(0.10), lineWidth: themeBackgroundType == "image" ? 3 : 1)
                            )

                            Text("Current Photo")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.primary)
                                .frame(width: 154)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var themeCustomizePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Customize")
                .font(.system(size: 18, weight: .bold))

            VStack(alignment: .leading, spacing: 18) {
                Picker("Background Type", selection: $themeBackgroundType) {
                    Text("Default Theme").tag("preset")
                    Text("Solid Color").tag("color")
                    Text("Photo").tag("image")
                }
                .pickerStyle(.segmented)

                if themeBackgroundType == "color" {
                    ColorPicker("Notch Background Color", selection: Binding(
                        get: { Color(hex: themeBackgroundColorHex) ?? .black },
                        set: { themeBackgroundColorHex = $0.toHex() }
                    ))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Background Opacity: \(Int(themeBackgroundOpacity * 100))%")
                        .font(.system(size: 13, weight: .semibold))
                    HStack(spacing: 8) {
                        Text("0%").font(.caption).foregroundColor(.secondary).frame(width: 30, alignment: .leading)
                        Slider(value: $themeBackgroundOpacity, in: 0.0...1.0, step: 0.05).labelsHidden()
                        Text("100%").font(.caption).foregroundColor(.secondary).frame(width: 34, alignment: .trailing)
                    }
                }

                if themeBackgroundType == "image" {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Background Blur: \(Int(themeBackgroundBlur))")
                            .font(.system(size: 13, weight: .semibold))
                        HStack(spacing: 8) {
                            Text("0").font(.caption).foregroundColor(.secondary).frame(width: 30, alignment: .leading)
                            Slider(value: $themeBackgroundBlur, in: 0.0...40.0, step: 1.0).labelsHidden()
                            Text("40").font(.caption).foregroundColor(.secondary).frame(width: 34, alignment: .trailing)
                        }
                    }

                    HStack(spacing: 10) {
                        Button("Choose Image...") {
                            chooseThemeImage()
                        }

                        if !themeBackgroundImagePath.isEmpty {
                            Button("Clear Image") {
                                clearThemeImage()
                            }
                        }
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
    }

    private func applyPreset(_ preset: ThemePreset) {
        themePresetID = preset.id
        themeBackgroundType = "preset"
        themeBackgroundOpacity = 1.0
    }

    private func chooseThemeImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }

        let appFolder = appSupport.appendingPathComponent("WaveNotch", isDirectory: true)
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)

        let destination = appFolder.appendingPathComponent("custom_bg_\(UUID().uuidString).\(url.pathExtension)")

        do {
            try FileManager.default.copyItem(at: url, to: destination)
            clearThemeImage(removeStoredPathOnly: true)
            themeBackgroundImagePath = destination.path
            themeBackgroundType = "image"
        } catch {
            print("Failed to copy background image: \(error)")
        }
    }

    private func clearThemeImage(removeStoredPathOnly: Bool = false) {
        if !themeBackgroundImagePath.isEmpty {
            try? FileManager.default.removeItem(atPath: themeBackgroundImagePath)
        }
        if !removeStoredPathOnly {
            themeBackgroundImagePath = ""
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

            if pomodoroInstalled {
                Section {
                    Toggle("Show Pomodoro Icon in Notch", isOn: $showPomodoroNotchTimer)
                    Toggle("Show Countdown next to Notch", isOn: $showPomodoroTimeText)
                    Toggle("Show Pomodoro Timer Banner", isOn: $showPomodoroTimerBanner)
                } header: {
                    Text("Pomodoro Timer")
                }
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
                        let offsetText = globalLyricOffset == 0.0 ? "0.0 s" : String(format: "%+.1f s", globalLyricOffset)
                        Text("Global Sync Offset: \(offsetText)")
                        HStack(spacing: 8) {
                            Text("-8.0s").font(.caption).foregroundColor(.secondary).frame(width: 36, alignment: .leading)
                            Slider(value: $globalLyricOffset, in: -8.0...8.0, step: 0.5).labelsHidden()
                            Text("+8.0s").font(.caption).foregroundColor(.secondary).frame(width: 36, alignment: .trailing)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Global Synchronization")
                } footer: {
                    Text("Applies to every song. Per-song offsets are saved with each song and can be adjusted from the player or shortcuts.")
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
    // ⚡️ HELPERS
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
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            print("Login Item Error: \(error)")
        }
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

private struct ThemePreviewThumbnail: View {
    let backgroundType: String
    let presetID: String
    let colorHex: String
    let imagePath: String
    let opacity: Double
    let blur: Double
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundType == "color" ? (Color(hex: colorHex) ?? .black) : .black)

                if backgroundType == "preset" {
                    ThemePresetBackground(presetID: presetID)
                        .frame(width: size.width, height: size.height)
                        .opacity(opacity)
                } else if backgroundType == "image", let image = NSImage(contentsOfFile: imagePath) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .opacity(opacity)
                        .blur(radius: blur)
                        .clipped()
                } else if backgroundType == "image" {
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 26, weight: .semibold))
                        Text("No Photo")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.secondary)
                }

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .clipped()
    }
}

// ---------------------------------------------------------
// 🎛️ DASHBOARD SETTINGS VIEW (DRAG & DROP LAYOUT)
// ---------------------------------------------------------
struct DashboardSettingsView: View {
    @ObservedObject var dashboardObject = DashboardManager.shared
    @State private var localOrder: [NotchWidgetType] = []

    @AppStorage("plugin_player_enabled") var playerEnabled = true
    @AppStorage("plugin_spotify_queue_enabled") var spotifyQueueEnabled = false
    @AppStorage("plugin_spotify_playlists_enabled") var spotifyPlaylistsEnabled = false
    @AppStorage("plugin_turntable_player_enabled") var turntableEnabled = false
    @AppStorage("plugin_cassette_tape_enabled") var cassetteEnabled = false
    @AppStorage("plugin_youtube_queue_enabled") var ytQueueEnabled = false
    @AppStorage("plugin_youtube_playlists_enabled") var ytPlaylistsEnabled = false
    @AppStorage("plugin_google_calendar_enabled") var calendarEnabled = false
    @AppStorage("plugin_pomodoro_timer_enabled") var pomodoroEnabled = false
    @AppStorage("plugin_clipboard_history_enabled") var clipboardEnabled = false
    @AppStorage("plugin_file_tray_enabled") var fileTrayEnabled = false
    @AppStorage("plugin_tasks_enabled") var tasksEnabled = false
    @AppStorage("plugin_kaomoji_board_enabled") var kaomojiEnabled = false
    @AppStorage("plugin_weather_enabled") var weatherEnabled = false
    @AppStorage("expandedPadding") var expandedPadding: Double = 16.0

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Dashboard Layout")
                .font(.system(size: 28, weight: .bold))

            Text("Drag and drop to prioritize how widgets appear side-by-side. You can now also choose whether to display the Music Player.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Text("Expanded Padding: \(Int(expandedPadding))px")
                    .font(.system(size: 14, weight: .semibold))

                HStack(spacing: 8) {
                    Text("8px")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .leading)
                    Slider(value: $expandedPadding, in: 8...40, step: 2)
                        .labelsHidden()
                    Text("40px")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )

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
                        dashboardObject.saveWidgetOrder(localOrder)
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
            localOrder = dashboardObject.getWidgetOrder()
        }
    }

    private func binding(for widget: NotchWidgetType) -> Binding<Bool> {
        switch widget {
        case .player: return $playerEnabled
        case .spotifyQueue: return $spotifyQueueEnabled
        case .spotifyPlaylists: return $spotifyPlaylistsEnabled
        case .turntable: return $turntableEnabled
        case .cassette: return $cassetteEnabled
        case .youtubeQueue: return $ytQueueEnabled
        case .youtubePlaylists: return $ytPlaylistsEnabled
        case .calendar: return $calendarEnabled
        case .pomodoro: return $pomodoroEnabled
        case .clipboard: return $clipboardEnabled
        case .fileTray: return $fileTrayEnabled
        case .tasks: return $tasksEnabled
        case .kaomoji: return $kaomojiEnabled
        case .weather: return $weatherEnabled
        }
    }
}
