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
    
    // ⚡️ USER SETTINGS
    @AppStorage("collapsedWidth") var storedCollapsedWidth: Double = 300.0
    @AppStorage("showSettingsButton") var showSettingsButton = true
    @AppStorage("enableHoverToExpand") var enableHoverToExpand = true
    @AppStorage("hoverDelay") var hoverDelay: Double = 0.0
    
    @AppStorage("showBannerOnControl") var showBannerOnControl = true
    @AppStorage("bannerDuration") var bannerDuration: Double = 3.5
    @AppStorage("showLyrics") var showLyrics = true
    @AppStorage("lyricOffset") var lyricOffset: Double = 0.0
    @AppStorage("showBannerLyrics") var showBannerLyrics = true
    @AppStorage("showGlowEffect") var showGlowEffect = true
    @AppStorage("visibleLyricLines") var visibleLyricLines = 3
    @AppStorage("invertSwipeDirection") var invertSwipeDirection = true
    @State private var isAppHidden = false
    
    @AppStorage("enableAppleMusic") var enableAppleMusic = false
    @AppStorage("enableSpotify") var enableSpotify = false
    @AppStorage("enableChrome") var enableChrome = false
    @AppStorage("enableBrave") var enableBrave = false
    @AppStorage("enableEdge") var enableEdge = false
    @AppStorage("enableSafari") var enableSafari = false
    
    @AppStorage("plugin_spotify_queue_enabled") var spotifyQueueEnabled = false
    @AppStorage("plugin_spotify_playlists_enabled") var spotifyPlaylistsEnabled = false
    
    @State private var isShowingBanner = false
    @State private var bannerText: String = ""
    @State private var bannerTask: Task<Void, Never>? = nil
    @State private var isShowingLyricBanner = false
    @State private var currentLyricText: String = ""
    
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
        // 1. Ask all connected screens for their top safe area (the notch)
        // 2. Grab the highest number.
        let actualNotchDepth = NSScreen.screens.map { $0.safeAreaInsets.top }.max() ?? 0
        
        // 3. A physical notch is always taller than 24px.
        // If it found one, use it. Otherwise, safely fall back to 32.
        return actualNotchDepth > 24 ? actualNotchDepth : 32
    }
    
    let bannerHeightAddon: CGFloat = 24
    
    var collapsedWidth: CGFloat { CGFloat(storedCollapsedWidth) }
    
    var activeWidgetsCount: Int {
        dashboardManager.activeWidgets.count
    }
    
    var expandedWidth: CGFloat {
        activeWidgetsCount <= 1 ? 400 : 520
    }
    
    var expandedHeight: CGFloat {
        let widgets = dashboardManager.activeWidgets
        if widgets.isEmpty { return notchHeight + 12 }
        
        // ⚡️ DYNAMIC HEIGHT ENGINE
        let rows = widgets.chunked(into: 2)
        var totalH: CGFloat = notchHeight + 12 // Start with top padding
        
        let playerH: CGFloat = (!nowPlaying.lyrics.isEmpty && showLyrics) ? (80 + 12 + CGFloat(visibleLyricLines) * 26.0) : 80
        
        for row in rows {
            var rowMaxH: CGFloat = 0
            for widget in row {
                let widgetH: CGFloat
                switch widget {
                case .player: widgetH = (row.count == 1) ? playerH : playerH + 20
                case .spotifyQueue: widgetH = 250
                case .spotifyPlaylists: widgetH = (row.count == 1) ? 120 : 120 
                case .weather: widgetH = 100
                default: widgetH = 160 // Fallback for Calendar
                }
                rowMaxH = max(rowMaxH, widgetH)
            }
            totalH += rowMaxH
        }
        
        totalH += CGFloat(max(0, rows.count - 1)) * 6 // add row spacing
        totalH += 12 // bottom padding
        
        return totalH
    }
    
    var body: some View {
        let hasMedia = nowPlaying.currentSong != "No Music" && nowPlaying.currentSong != "NOT_PLAYING"
        
        let currentWidth: CGFloat = isExpanded ? expandedWidth : collapsedWidth
        let currentCollapsedHeight: CGFloat = (isShowingBanner || isShowingLyricBanner) ? (notchHeight + bannerHeightAddon) : notchHeight
        let currentHeight: CGFloat = isExpanded ? expandedHeight : currentCollapsedHeight
        
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // 1. BACKGROUND LAYER (Precise hover detection lives here)
                backgroundLayer(currentWidth: currentWidth, currentHeight: currentHeight)
                
                // 2. CONTENT LAYERS
                collapsedLayer(hasMedia: hasMedia, currentCollapsedHeight: currentCollapsedHeight)
                expandedLayer(expandedHeight: expandedHeight)
                
                // 3. SETTINGS ICON
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
            .clipShape(DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: 16))
            .animation(
                isExpanded
                ? .spring(response: 0.35, dampingFraction: 0.75, blendDuration: 0.1)
                : .spring(response: 0.30, dampingFraction: 1.0, blendDuration: 0.1),
                value: isExpanded
            )
            .animation(.spring(response: 0.30, dampingFraction: 1.0, blendDuration: 0.1), value: isShowingBanner || isShowingLyricBanner)
            
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
            KeyboardShortcuts.onKeyDown(for: .toggleAppVisibility) { isAppHidden.toggle() }
        }
        .onDisappear {
            if let keyLocal = localMediaKeyMonitor { NSEvent.removeMonitor(keyLocal) }
            if let keyGlobal = globalMediaKeyMonitor { NSEvent.removeMonitor(keyGlobal) }
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
            }
        }
        .onChange(of: nowPlaying.currentSong) { _, newSong in
            guard newSong != "No Music" && newSong != "NOT_PLAYING" else { return }
            if showGlowEffect {
                glowOpacity = 0.0; glowRotation = 0.0
                withAnimation(.easeIn(duration: 1.2)) { glowOpacity = 1.0 }
                withAnimation(.easeInOut(duration: 5.0)) { glowRotation = 360 }
                withAnimation(.easeOut(duration: 2.0).delay(3.0)) { glowOpacity = 0.0 }
            }
            triggerBanner(text: newSong, duration: bannerDuration)
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
        DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: 16)
            .fill(Color.black)
            .frame(width: currentWidth, height: currentHeight)
            .contentShape(DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: 16))
            .overlay(
                DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: 16)
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
    private func collapsedLayer(hasMedia: Bool, currentCollapsedHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ZStack {
                    if hasMedia && nowPlaying.artworkURL != nil {
                        AsyncImage(url: nowPlaying.artworkURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: { Color.gray.opacity(0.3) }
                            .frame(width: 20, height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .id(nowPlaying.currentSong)
                            .transition(.panRotate(direction: skipDirection))
                    } else {
                        Image(systemName: "music.note").foregroundColor(nowPlaying.isPlaying ? .white : .gray).font(.system(size: 14, weight: .bold))
                    }
                }
                .frame(width: 24, alignment: .leading)
                
                Spacer()
                
                WaveformView(isPlaying: nowPlaying.isPlaying, color: nowPlaying.artworkDominantColor).frame(width: 24, alignment: .trailing)
            }
            .padding(.horizontal, 24)
            .frame(height: notchHeight)
            
            let showAnyBanner: Bool = (isShowingBanner || isShowingLyricBanner) && hasMedia
            if showAnyBanner {
                ZStack {
                    if isShowingBanner {
                        MarqueeText(text: bannerText, font: .system(size: 12, weight: .bold), alignment: .center)
                            .foregroundColor(nowPlaying.artworkDominantColor)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .id("banner_\(bannerText)")
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
    
    @ViewBuilder
    private func expandedLayer(expandedHeight: CGFloat) -> some View {
        let widgets = dashboardManager.activeWidgets
        let availableWidth = expandedWidth - 32 - 6 // total horizontal padding (16*2) and inner spacing (6)
        
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
                
                VStack(spacing: 6) {
                    ForEach(0..<rows.count, id: \.self) { rowIndex in
                        let row = rows[rowIndex]
                        HStack(alignment: .center, spacing: 6) {
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
                                    expandedWidth: availableWidth * r1,
                                    isCompact: true,
                                    skipDirection: $skipDirection,
                                    glowOpacity: $glowOpacity,
                                    onSwipe: { forward in self.executeSkip(forward: forward) }
                                )
                                .frame(width: availableWidth * r1)
                                
                                WidgetFactoryView(
                                    widgetType: w2,
                                    nowPlaying: nowPlaying,
                                    expandedWidth: availableWidth * r2,
                                    isCompact: true,
                                    skipDirection: $skipDirection,
                                    glowOpacity: $glowOpacity,
                                    onSwipe: { forward in self.executeSkip(forward: forward) }
                                )
                                .frame(width: availableWidth * r2)
                                
                            } else {
                                // Single widget row (e.g. last item in odd-count list)
                                WidgetFactoryView(
                                    widgetType: row[0],
                                    nowPlaying: nowPlaying,
                                    expandedWidth: availableWidth,
                                    isCompact: false,
                                    skipDirection: $skipDirection,
                                    glowOpacity: $glowOpacity,
                                    onSwipe: { forward in self.executeSkip(forward: forward) }
                                )
                                .frame(width: availableWidth)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, notchHeight + 12)
        .frame(width: expandedWidth, height: expandedHeight)
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
                await MainActor.run {
                    withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) { isShowingBanner = false }
                    updateLyricBanner()
                }
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
