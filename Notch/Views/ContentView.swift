import SwiftUI
import Combine
import KeyboardShortcuts

enum AppTab {
    case player
    case playlist
}

struct ContentView: View {
    @State private var isExpanded = false
    @ObservedObject private var nowPlaying = NowPlayingManager.shared
    @State private var currentTab: AppTab = .player
    @StateObject private var dashboardManager = DashboardManager.shared
    @ObservedObject private var pomodoroTimer = PomodoroTimerManager.shared

    // ⚡️ USER SETTINGS
    @AppStorage("collapsedWidth") var storedCollapsedWidth: Double = 300.0
    @AppStorage("showSettingsButton") var showSettingsButton = true
    @AppStorage("enableHoverToExpand") var enableHoverToExpand = true
    @AppStorage("hoverDelay") var hoverDelay: Double = 0.0

    @AppStorage("showBannerOnControl") var showBannerOnControl = true
    @AppStorage("bannerDuration") var bannerDuration: Double = 3.5
    @AppStorage("showLyrics") var showLyrics = true
    @AppStorage("showBannerLyrics") var showBannerLyrics = true
    @AppStorage("showGlowEffect") var showGlowEffect = true
    @AppStorage("visibleLyricLines") var visibleLyricLines = 3
    @AppStorage("invertSwipeDirection") var invertSwipeDirection = true
    @State private var isAppHidden = false

    // ⚡️ THEME
    @AppStorage("themeBackgroundType") var themeBackgroundType: String = "color"
    @AppStorage("themeBackgroundColorHex") var themeBackgroundColorHex: String = "000000"
    @AppStorage("themeBackgroundImagePath") var themeBackgroundImagePath: String = ""
    @AppStorage("themeBackgroundOpacity") var themeBackgroundOpacity: Double = 1.0
    @AppStorage("themeBackgroundBlur") var themeBackgroundBlur: Double = 0.0

    @AppStorage("expandedPadding") var expandedPadding: Double = 16.0

    @AppStorage("enableAppleMusic") var enableAppleMusic = false
    @AppStorage("enableSpotify") var enableSpotify = false
    @AppStorage("enableChrome") var enableChrome = false
    @AppStorage("enableBrave") var enableBrave = false
    @AppStorage("enableEdge") var enableEdge = false
    @AppStorage("enableSafari") var enableSafari = false

    @AppStorage("plugin_spotify_queue_enabled") var spotifyQueueEnabled = false
    @AppStorage("plugin_spotify_playlists_enabled") var spotifyPlaylistsEnabled = false
    @AppStorage("plugin_pomodoro_timer_enabled") var pomodoroPluginEnabled = false
    @AppStorage("pomodoro_show_notch_timer") var showPomodoroNotchTimer = true
    @AppStorage("pomodoro_show_time_text") var showPomodoroTimeText = true
    @AppStorage("pomodoro_show_timer_banner") var showPomodoroTimerBanner = false

    @State private var isShowingBanner = false
    @State private var bannerText: String = ""
    @State private var bannerTask: Task<Void, Never>? = nil
    @State private var isShowingLyricBanner = false
    @State private var currentLyricText: String = ""

    @State private var cachedThemeImage: NSImage? = nil

    @State private var hoverTask: Task<Void, Never>? = nil

    @State private var localMediaKeyMonitor: Any?
    @State private var globalMediaKeyMonitor: Any?

    @State private var glowRotation: Double = 0.0
    @State private var glowOpacity: Double = 0.0
    @State private var skipDirection: Int = 1
    @State private var lastSongChangeTime: Date = Date.distantPast
    let lyricTimer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    let hoverCheckTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    // ---------------------------------------------------------
    // ⚡️ THE BULLETPROOF NOTCH DETECTION
    // Agent apps sometimes get generic data from NSScreen.main.
    // This loops through EVERY connected display, finds the physical
    // camera notch, and grabs its exact pixel depth.
    // ---------------------------------------------------------
    var notchHeight: CGFloat {
        let actualNotchDepth = NSScreen.screens.map { $0.safeAreaInsets.top }.max() ?? 0

        // 3. A physical notch is always taller than 24px.
        // If it found one, use it. Otherwise, safely fall back to 32.
        return actualNotchDepth > 24 ? actualNotchDepth : 32
    }

    let bannerHeightAddon: CGFloat = 24
    let notchBlendRadius: CGFloat = 16
    let expandedRowSpacing: CGFloat = 6
    let playlistWidgetHeight: CGFloat = 144
    let pomodoroWidgetHeight: CGFloat = 160
    let playerWidgetHeightBuffer: CGFloat = 18

    var collapsedWidth: CGFloat { CGFloat(storedCollapsedWidth) }

    var activeWidgetsCount: Int {
        dashboardManager.activeWidgets.count
    }

    var expandedWidth: CGFloat {
        activeWidgetsCount <= 1 ? 340 : 540
    }

    var expandedHeight: CGFloat {
        let widgets = dashboardManager.activeWidgets
        if widgets.isEmpty { return notchHeight + CGFloat(expandedPadding) * 2 }

        let rows = widgets.chunked(into: 2)
        let pad = CGFloat(expandedPadding)
        var totalH: CGFloat = notchHeight + pad

        for row in rows {
            let isCompact = rowUsesCompactPlayerLayout(row)
            let playerH = playerWidgetHeight(isCompact: isCompact)

            var rowMaxH: CGFloat = 0
            for widget in row {
                rowMaxH = max(rowMaxH, expandedWidgetHeight(for: widget, playerHeight: playerH))
            }
            totalH += rowMaxH
        }

        totalH += CGFloat(max(0, rows.count - 1)) * expandedRowSpacing
        totalH += pad

        return totalH
    }
    var body: some View {
        let hasMedia = nowPlaying.currentSong != "No Music" && nowPlaying.currentSong != "NOT_PLAYING"

        let currentWidth: CGFloat = isExpanded ? expandedWidth : collapsedWidth
        let showsCollapsedBanner = isShowingBanner || isShowingLyricBanner || shouldShowPomodoroTimerBanner
        let currentCollapsedHeight: CGFloat = showsCollapsedBanner ? (notchHeight + bannerHeightAddon) : notchHeight
        let currentHeight: CGFloat = isExpanded ? expandedHeight : currentCollapsedHeight

        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // 1. BACKGROUND LAYER (Precise hover detection lives here)
                backgroundLayer(currentWidth: currentWidth, currentHeight: currentHeight)

                // 2. CONTENT LAYERS
                collapsedLayer(hasMedia: hasMedia, currentCollapsedHeight: currentCollapsedHeight)
                expandedLayer(expandedHeight: expandedHeight)

                settingsButtonLayer
            }
            .frame(width: currentWidth, height: currentHeight, alignment: .top)
            .onChange(of: currentWidth) { _, _ in
                NotificationCenter.default.post(name: NSNotification.Name("CenterAppWindow"), object: nil)
            }
            .contextMenu {
                Button(action: { SettingsWindowManager.shared.showSettings() }) {
                    Text("Settings")
                    Image(systemName: "gearshape")
                }
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Text("Quit WaveNotch")
                    Image(systemName: "power")
                }
            }
            .clipShape(DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: notchBlendRadius))
            .animation(
                isExpanded
                ? .spring(response: 0.35, dampingFraction: 0.75, blendDuration: 0.1)
                : .spring(response: 0.30, dampingFraction: 1.0, blendDuration: 0.1),
                value: isExpanded
            )
            .animation(.spring(response: 0.30, dampingFraction: 1.0, blendDuration: 0.1), value: showsCollapsedBanner)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .opacity(isAppHidden ? 0 : 1)
        .allowsHitTesting(!isAppHidden)
        .onAppear {
            localMediaKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .systemDefined) { event in
                handleSystemKey(event: event)
                return event
            }
            globalMediaKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { event in
                handleSystemKey(event: event)
            }
            registerKeyboardShortcuts()
            loadThemeImage()
        }
        .onDisappear {
            if let keyLocal = localMediaKeyMonitor { NSEvent.removeMonitor(keyLocal) }
            if let keyGlobal = globalMediaKeyMonitor { NSEvent.removeMonitor(keyGlobal) }
        }
        .onChange(of: themeBackgroundImagePath) { _, _ in
            loadThemeImage()
        }
        .onChange(of: isExpanded) { _, expanded in
            if !expanded {
                updateLyricBanner()
                currentTab = .player
            } else {
                dashboardManager.refreshWidgets()
                // ⚡️ REFETCH GOOGLE EVENTS: Ensure schedule is fresh on expand
                if GoogleCalendarManager.shared.isAuthenticated {
                    GoogleCalendarManager.shared.fetchTodaysEvents()
                }

                // ⚡️ REFETCH SPOTIFY: Ensure data isn't stuck in "Fetching..."
                if !SpotifyAuthManager.shared.accessToken.isEmpty {
                    if SpotifyAuthManager.shared.currentQueueItems.isEmpty {
                        SpotifyAuthManager.shared.fetchQueue()
                    }
                    if SpotifyAuthManager.shared.playlists.isEmpty {
                        SpotifyAuthManager.shared.fetchPlaylists()
                    }
                }
            }
        }
        .onChange(of: nowPlaying.currentSong) { _, newSong in
            handleSongChange(newSong)
        }
        .onReceive(hoverCheckTimer) { _ in
            if !isExpanded && nowPlaying.isPlaying {
                nowPlaying.currentTime += 0.1
                nowPlaying.updateActiveLyric()
            }

            guard let screen = NSScreen.main else { return }
            let mouseLoc = NSEvent.mouseLocation

            let currentW = isExpanded ? expandedWidth : collapsedWidth
            let currentH = isExpanded ? expandedHeight : currentCollapsedHeight

            // Reconstruct the notch window frame in screen coordinates
            let panelRect = CGRect(x: (screen.frame.width - currentW) / 2, y: screen.frame.height - currentH, width: currentW, height: currentH)

            let isHovering = panelRect.contains(mouseLoc)

            if isHovering {
                if !isExpanded && enableHoverToExpand {
                    if hoverTask == nil {
                        hoverTask = Task {
                            if hoverDelay > 0 {
                                try? await Task.sleep(nanoseconds: UInt64(hoverDelay * 1_000_000_000))
                            }
                            guard !Task.isCancelled else { return }
                            await MainActor.run {
                                isExpanded = true
                                isShowingBanner = false
                                isShowingLyricBanner = false
                                bannerTask?.cancel()
                            }
                        }
                    }
                }
            } else {
                if hoverTask != nil {
                    hoverTask?.cancel()
                    hoverTask = nil
                }
                if isExpanded {
                    isExpanded = false
                }
            }
        }
        .onChange(of: nowPlaying.activeLyricIndex) { _, _ in updateLyricBanner() }
        .onChange(of: showBannerLyrics) { _, _ in updateLyricBanner() }
        .onChange(of: nowPlaying.lyrics) { _, _ in updateLyricBanner() }
        .onChange(of: nowPlaying.isPlaying) { _, newState in
            updateLyricBanner()
            guard showBannerOnControl else { return }
            guard nowPlaying.currentSong != "No Music" && nowPlaying.currentSong != "NOT_PLAYING" else { return }
            guard Date().timeIntervalSince(lastSongChangeTime) > 0.5 else { return }
            triggerBanner(text: newState ? "Resumed" : "Paused", duration: 1.5)
        }
        .edgesIgnoringSafeArea(.all)
    }

    @ViewBuilder
    private func backgroundLayer(currentWidth: CGFloat, currentHeight: CGFloat) -> some View {
        DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: notchBlendRadius)
            .fill(themeBackgroundType == "color" ? (Color(hex: themeBackgroundColorHex) ?? .black) : .black)
            .opacity(themeBackgroundType == "color" ? themeBackgroundOpacity : 1.0)
            .overlay(
                Group {
                    if themeBackgroundType == "image", let nsImage = cachedThemeImage {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: currentWidth, height: currentHeight)
                            .opacity(themeBackgroundOpacity)
                            .blur(radius: themeBackgroundBlur)
                            .clipShape(DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: notchBlendRadius))
                    }
                }
            )
            .frame(width: currentWidth, height: currentHeight)
            .contentShape(DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: notchBlendRadius))
            .onTapGesture(count: 2) {
                SettingsWindowManager.shared.showSettings()
            }
            .overlay(
                DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: notchBlendRadius)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: nowPlaying.artworkDominantColor, location: 0.1),
                                .init(color: .white, location: 0.12),
                                .init(color: .clear, location: 0.131)
                            ]),
                            center: .center,
                            angle: .degrees(glowRotation)
                        ),
                        lineWidth: 2.5
                    )
                    .opacity(glowOpacity)
                    .allowsHitTesting(false)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 12, y: 6)
            .zIndex(1)
    }

    @ViewBuilder
    private var settingsButtonLayer: some View {
        if isExpanded && showSettingsButton {
            HStack {
                Spacer()
                Button(action: { SettingsWindowManager.shared.showSettings() }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
                .frame(width: 24, height: 24)
            }
            .padding(.trailing, 20)
            .padding(.top, 10)
            .zIndex(4)
        }
    }

    @ViewBuilder
    private func collapsedLayer(hasMedia: Bool, currentCollapsedHeight: CGFloat) -> some View {
        let showTimerIcon = pomodoroPluginEnabled && showPomodoroNotchTimer
        let showTimerText = pomodoroPluginEnabled && showPomodoroTimeText
        let showTimerBanner = shouldShowPomodoroTimerBanner

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ZStack {
                    if showTimerIcon {
                        pomodoroCollapsedProgressIcon
                    } else if hasMedia && nowPlaying.artworkURL != nil {
                        AsyncImage(url: nowPlaying.artworkURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: { Color.gray.opacity(0.3) }
                            .frame(width: 20, height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .id(nowPlaying.currentSong)
                            .transition(.panRotate(direction: skipDirection))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.1))
                            Image(systemName: "music.note")
                                .foregroundColor(nowPlaying.isPlaying ? .white : .gray)
                                .font(.system(size: 10, weight: .bold))
                        }
                        .frame(width: 20, height: 20)
                    }
                }
                .frame(width: 24, alignment: .leading)

                Spacer()

                if showTimerText {
                    Text(pomodoroTimer.timeText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(pomodoroTimer.mode.color)
                        .frame(width: 56, alignment: .trailing)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pomodoroTimer.timeText)
                } else {
                    WaveformView(isPlaying: nowPlaying.isPlaying, color: nowPlaying.artworkDominantColor).frame(width: 24, alignment: .trailing)
                }
            }
            .padding(.horizontal, 24)
            .frame(height: notchHeight)

            let showAnyBanner: Bool = isShowingBanner || showTimerBanner || (isShowingLyricBanner && hasMedia)
            if showAnyBanner {
                ZStack {
                    if isShowingBanner {
                        MarqueeText(text: bannerText, font: .system(size: 12, weight: .bold), alignment: .center)
                            .foregroundColor(nowPlaying.artworkDominantColor)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .id("banner_\(bannerText)")
                    } else if showTimerBanner {
                        HStack(spacing: 6) {
                            Image(systemName: "timer")
                                .font(.system(size: 11, weight: .bold))
                            Text("\(pomodoroTimer.mode.title) \(pomodoroTimer.timeText)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pomodoroTimer.timeText)
                                .monospacedDigit()
                            Text(pomodoroTimer.roundText)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        .foregroundColor(pomodoroTimer.mode.color)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    } else if isShowingLyricBanner {
                        MarqueeText(text: currentLyricText, font: .system(size: 12, weight: .bold), alignment: .center)
                            .foregroundColor(nowPlaying.artworkDominantColor)
                            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity.combined(with: .move(edge: .leading))))
                            .id("lyric_\(currentLyricText)")
                    }
                }
                .frame(height: bannerHeightAddon)
                .padding(.horizontal, 24)
                .clipped()
            }
        }
        .frame(width: collapsedWidth, height: currentCollapsedHeight)
        .opacity(isExpanded ? 0 : 1)
        .scaleEffect(isExpanded ? 0.95 : 1.0, anchor: .top)
        .allowsHitTesting(!isExpanded)
        .onTapGesture {
            if !isExpanded {
                isExpanded = true
                isShowingBanner = false
                isShowingLyricBanner = false
                bannerTask?.cancel()
            }
        }
        .zIndex(2)
    }

    private var shouldShowPomodoroNotchTimer: Bool {
        pomodoroPluginEnabled && showPomodoroNotchTimer
    }

    private var shouldShowPomodoroTimerBanner: Bool {
        pomodoroPluginEnabled && showPomodoroTimerBanner && pomodoroTimer.isRunning && !isExpanded
    }

    private var pomodoroCollapsedProgressIcon: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: 2)
            Circle()
                .trim(from: 0, to: max(0.001, pomodoroTimer.progress))
                .stroke(pomodoroTimer.mode.color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "clock.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(width: 22, height: 22)
    }

    private func expandedWidgetHeight(for widget: NotchWidgetType, playerHeight: CGFloat) -> CGFloat {
        switch widget {
        case .player: return playerHeight
        case .spotifyQueue, .youtubeQueue: return 250
        case .spotifyPlaylists, .youtubePlaylists: return playlistWidgetHeight
        case .pomodoro: return pomodoroWidgetHeight
        case .clipboard: return 220
        case .kaomoji: return 220
        case .weather: return 132
        default: return 160
        }
    }

    private func playerWidgetHeight(isCompact: Bool) -> CGFloat {
        let hasMedia = nowPlaying.currentSong != "No Music" && nowPlaying.currentSong != "NOT_PLAYING"
        let topRowHeight: CGFloat = 40
        let compactControlsHeight: CGFloat = isCompact && hasMedia ? 38 : 0
        let progressHeight: CGFloat = hasMedia ? 20 : 0
        let lyricsHeight: CGFloat = (hasMedia && !nowPlaying.lyrics.isEmpty && showLyrics) ? (8 + CGFloat(visibleLyricLines) * 26.0) : 0
        let verticalPadding: CGFloat = 24

        return topRowHeight + compactControlsHeight + progressHeight + lyricsHeight + verticalPadding + playerWidgetHeightBuffer
    }

    private func rowUsesCompactPlayerLayout(_ row: [NotchWidgetType]) -> Bool {
        row.count > 1
    }

    @ViewBuilder
    private func expandedLayer(expandedHeight: CGFloat) -> some View {
        let widgets = dashboardManager.activeWidgets
        let pad = CGFloat(expandedPadding)
        let sideInset = notchBlendRadius + pad
        let contentWidth = expandedWidth - (sideInset * 2)
        let splitRowWidth = contentWidth - expandedRowSpacing

        VStack(spacing: 0) {
            if widgets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No widgets enabled.")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.gray)
                    Text("Go to Settings > Layout to enable plugins.")
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // ⚡️ DYNAMIC ROW-BASED LAYOUT
                let rows = widgets.chunked(into: 2)

                VStack(spacing: expandedRowSpacing) {
                    ForEach(0..<rows.count, id: \.self) { rowIndex in
                        let row = rows[rowIndex]
                        let isCompact = rowUsesCompactPlayerLayout(row)
                        let playerH = playerWidgetHeight(isCompact: isCompact)

                        let rowMaxH = row
                            .map { expandedWidgetHeight(for: $0, playerHeight: playerH) }
                            .max() ?? playerH

                        HStack(alignment: .center, spacing: expandedRowSpacing) {
                            if row.count == 2 {
                                let w1 = row[0]
                                let w2 = row[1]

                                // Ratios: Spotify Queue is always 0.4 (Minor), all others split 1:1
                                let r1: CGFloat = {
                                    if w1 == .spotifyQueue { return 0.4 }
                                    if w2 == .spotifyQueue { return 0.6 }
                                    return 0.5
                                }()
                                let r2 = 1.0 - r1

                                WidgetFactoryView(
                                    widgetType: w1,
                                    nowPlaying: nowPlaying,
                                    expandedWidth: splitRowWidth * r1,
                                    isCompact: true,
                                    skipDirection: $skipDirection,
                                    glowOpacity: $glowOpacity,
                                    onSwipe: { forward in self.executeSkip(forward: forward) }
                                )
                                .frame(width: splitRowWidth * r1, height: rowMaxH)
                                .clipped(when: w1 != .player)

                                WidgetFactoryView(
                                    widgetType: w2,
                                    nowPlaying: nowPlaying,
                                    expandedWidth: splitRowWidth * r2,
                                    isCompact: true,
                                    skipDirection: $skipDirection,
                                    glowOpacity: $glowOpacity,
                                    onSwipe: { forward in self.executeSkip(forward: forward) }
                                )
                                .frame(width: splitRowWidth * r2, height: rowMaxH)
                                .clipped(when: w2 != .player)

                            } else {
                                // Single widget row (e.g. last item in odd-count list)
                                WidgetFactoryView(
                                    widgetType: row[0],
                                    nowPlaying: nowPlaying,
                                    expandedWidth: contentWidth,
                                    isCompact: isCompact,
                                    skipDirection: $skipDirection,
                                    glowOpacity: $glowOpacity,
                                    onSwipe: { forward in self.executeSkip(forward: forward) }
                                )
                                .frame(width: contentWidth, height: rowMaxH)
                                .clipped(when: row[0] != .player)
                            }
                        }
                        .frame(width: contentWidth)
                    }
                }
            }
        }
        .padding(.horizontal, sideInset)
        .padding(.top, notchHeight + pad)
        .padding(.bottom, pad)
        .frame(width: expandedWidth, height: expandedHeight, alignment: .top)
        .opacity(isExpanded ? 1 : 0)
        .scaleEffect(isExpanded ? 1.0 : 0.95, anchor: .top)
        .allowsHitTesting(isExpanded)
        .zIndex(3)
    }

    private func executeSkip(forward: Bool) {
        skipDirection = forward ? 1 : -1
        if forward {
            nowPlaying.skipForward()
        } else {
            nowPlaying.skipBackward()
        }
        triggerBanner(text: forward ? "Skipped Forward" : "Skipped Back", duration: 1.5)
    }

    private func registerKeyboardShortcuts() {
        KeyboardShortcuts.onKeyDown(for: .toggleAppVisibility) {
            isAppHidden.toggle()
        }
        KeyboardShortcuts.onKeyDown(for: .toggleLiveLyrics) {
            showLyrics.toggle()
        }
        KeyboardShortcuts.onKeyDown(for: .toggleBannerLyrics) {
            showBannerLyrics.toggle()
            updateLyricBanner()
        }
        KeyboardShortcuts.onKeyDown(for: .toggleBanner) {
            showBannerOnControl.toggle()
        }
        KeyboardShortcuts.onKeyDown(for: .increaseOffset) {
            nowPlaying.adjustCurrentSongLyricOffset(by: 0.5)
            triggerBanner(text: "Lyrics Earlier \(formatSignedOffset(nowPlaying.currentSongLyricOffset))", duration: 1.2)
        }
        KeyboardShortcuts.onKeyDown(for: .decreaseOffset) {
            nowPlaying.adjustCurrentSongLyricOffset(by: -0.5)
            triggerBanner(text: "Lyrics Later \(formatSignedOffset(nowPlaying.currentSongLyricOffset))", duration: 1.2)
        }
        KeyboardShortcuts.onKeyDown(for: .increaseLines) {
            visibleLyricLines = min(5, visibleLyricLines == 1 ? 3 : visibleLyricLines + 2)
        }
        KeyboardShortcuts.onKeyDown(for: .decreaseLines) {
            visibleLyricLines = max(1, visibleLyricLines == 5 ? 3 : visibleLyricLines - 2)
        }
        KeyboardShortcuts.onKeyDown(for: .increaseDelay) {
            hoverDelay = min(3.0, hoverDelay + 0.1)
        }
        KeyboardShortcuts.onKeyDown(for: .decreaseDelay) {
            hoverDelay = max(0.0, hoverDelay - 0.1)
        }
    }

    private func formatSignedOffset(_ value: Double) -> String {
        value == 0.0 ? "0.0s" : String(format: "%+.1fs", value)
    }

    private func handleSongChange(_ newSong: String) {
        guard newSong != "No Music" else { return }
        guard newSong != "NOT_PLAYING" else { return }

        if showGlowEffect {
            glowOpacity = 0.0
            glowRotation = 0.0
            withAnimation(.easeIn(duration: 1.2)) { glowOpacity = 1.0 }
            withAnimation(.easeInOut(duration: 5.0)) { glowRotation = 360 }
            withAnimation(.easeOut(duration: 2.0).delay(3.0)) { glowOpacity = 0.0 }
        }

        triggerBanner(text: newSong, duration: bannerDuration)
    }

    private func loadThemeImage() {
        guard themeBackgroundType == "image", !themeBackgroundImagePath.isEmpty else {
            cachedThemeImage = nil
            return
        }

        let path = themeBackgroundImagePath
        DispatchQueue.global(qos: .userInitiated).async {
            guard let image = NSImage(contentsOfFile: path) else { return }

            // ⚡️ DOWN-SAMPLE MASSIVE IMAGES
            // Large 4K images cause massive rendering lag during fast layout updates in the Notch.
            let maxWidth: CGFloat = 1200
            if image.size.width > maxWidth {
                let scale = maxWidth / image.size.width
                let newSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)
                let newImage = NSImage(size: newSize)
                newImage.lockFocus()
                image.draw(in: NSRect(origin: .zero, size: newSize), from: .zero, operation: .copy, fraction: 1.0)
                newImage.unlockFocus()
                DispatchQueue.main.async { self.cachedThemeImage = newImage }
            } else {
                DispatchQueue.main.async { self.cachedThemeImage = image }
            }
        }
    }

    private func handleSystemKey(event: NSEvent) {
        if event.subtype.rawValue == 8 {
            let data = event.data1
            let keyCode = (data & 0xFFFF0000) >> 16
            let keyFlags = (data & 0x0000FFFF)
            let keyState = (((keyFlags & 0xFF00) >> 8)) == 0xA

            if keyState {
                if keyCode == 19 { skipDirection = -1 }
                else if keyCode == 20 { skipDirection = 1 }
            }
        }
    }

    private func updateLyricBanner() {
        guard showBannerLyrics, !isExpanded, nowPlaying.isPlaying, !nowPlaying.lyrics.isEmpty, nowPlaying.activeLyricIndex >= 0, nowPlaying.activeLyricIndex < nowPlaying.lyrics.count else {
            withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) { isShowingLyricBanner = false }; return
        }
        let newLyric = nowPlaying.lyrics[nowPlaying.activeLyricIndex].text
        if newLyric.trimmingCharacters(in: .whitespaces).isEmpty {
            withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) { isShowingLyricBanner = false }
        }
        else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                currentLyricText = newLyric
                isShowingLyricBanner = true
            }
        }
    }

    private func triggerBanner(text: String, duration: Double) {
        if !isExpanded {
            bannerText = text
            withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) { isShowingBanner = true }

            let sleepTime = UInt64(duration * 1_000_000_000)
            bannerTask?.cancel()
            bannerTask = Task {
                try? await Task.sleep(nanoseconds: sleepTime)
                guard !Task.isCancelled else { return }
                await MainActor.run { withAnimation { isShowingBanner = false }; updateLyricBanner() }
            }
        }
    }
}

struct PanRotateModifier: ViewModifier {
    let offset: CGFloat
    let angle: Double
    let opacity: Double
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0))
            .scaleEffect(scale)
            .opacity(opacity)
    }
}

extension AnyTransition {
    static func panRotate(direction: Int) -> AnyTransition {
        return .asymmetric(
            insertion: .modifier(
                active: PanRotateModifier(offset: CGFloat(direction * 25), angle: Double(direction * 60), opacity: 0, scale: 0.9),
                identity: PanRotateModifier(offset: 0, angle: 0, opacity: 1, scale: 1.0)
            ),
            removal: .modifier(
                active: PanRotateModifier(offset: CGFloat(direction * -25), angle: Double(direction * -60), opacity: 0, scale: 0.9),
                identity: PanRotateModifier(offset: 0, angle: 0, opacity: 1, scale: 1.0)
            )
        )
    }

    static func dynamicPanRotate(direction: Int) -> AnyTransition {
        return .asymmetric(
            insertion: .modifier(
                active: PanRotateModifier(offset: CGFloat(direction * 80), angle: Double(direction * 90), opacity: 0, scale: 0.75),
                identity: PanRotateModifier(offset: 0, angle: 0, opacity: 1, scale: 1.0)
            ),
            removal: .modifier(
                active: PanRotateModifier(offset: CGFloat(direction * -80), angle: Double(direction * -90), opacity: 0, scale: 0.75),
                identity: PanRotateModifier(offset: 0, angle: 0, opacity: 1, scale: 1.0)
            )
        )
    }
}
