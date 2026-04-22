import SwiftUI
import AppKit
import Combine
import KeyboardShortcuts

struct ContentView: View {
    @State private var isExpanded = false
    @StateObject private var nowPlaying = NowPlayingManager()
    @StateObject private var dashboardManager = DashboardManager.shared
    
    // ⚡️ USER SETTINGS
    @AppStorage("enableCalendar") var enableCalendar = false
    @StateObject private var calendarManager = CalendarManager.shared
    
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
    
    @AppStorage("enableSpotifyPlus_enabled") private var enableSpotifyPlus = false
    @AppStorage("spotifyAccessToken") private var spotifyAccessToken = ""
    
    @State private var isShowingBanner = false
    @State private var bannerText: String = ""
    @State private var bannerTask: Task<Void, Never>? = nil
    @State private var isShowingLyricBanner = false
    @State private var currentLyricText: String = ""
    
    @State private var lastSwipeTime: Date = Date()
    @State private var localEventMonitor: Any?
    @State private var globalEventMonitor: Any?
    @State private var hoverTask: Task<Void, Never>? = nil
    
    @State private var localMediaKeyMonitor: Any?
    @State private var globalMediaKeyMonitor: Any?
    
    @State private var glowRotation: Double = 0.0
    @State private var glowOpacity: Double = 0.0
    @State private var skipDirection: Int = 1
    @State private var lastSongChangeTime: Date = Date.distantPast
    let lyricTimer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    
    var notchHeight: CGFloat {
        let actualNotchDepth = NSScreen.screens.map { $0.safeAreaInsets.top }.max() ?? 0
        return actualNotchDepth > 24 ? actualNotchDepth : 32
    }
    
    let bannerHeightAddon: CGFloat = 24
    
    var collapsedWidth: CGFloat { CGFloat(storedCollapsedWidth) }
    
    var activeWidgets: [NotchWidgetType] {
        dashboardManager.activeLayout.filter { type in
            if type == .playlist {
                let isSpotifyActive = nowPlaying.lastActiveBrowser == "SpotifyNative" || (nowPlaying.lastActiveBrowser?.contains("Spotify") ?? false)
                return isSpotifyActive && enableSpotifyPlus && !spotifyAccessToken.isEmpty
            }
            return true
        }
    }
    
    var expandedWidth: CGFloat {
        activeWidgets.count <= 1 ? 440 : 720
    }
    
    var expandedHeight: CGFloat {
        let widgets = activeWidgets
        if widgets.isEmpty { return notchHeight + 12 }
        
        let playerH: CGFloat = (!nowPlaying.lyrics.isEmpty && showLyrics) ? (132 + 12 + CGFloat(visibleLyricLines) * 26.0) : 132
        
        var rowHeights: [CGFloat] = []
        var currentRowMax: CGFloat = 0
        
        for (index, widget) in widgets.enumerated() {
            let widgetH: CGFloat
            switch widget {
            case .nowPlaying: widgetH = playerH
            case .playlist: widgetH = 250
            case .calendar: widgetH = 100
            case .weather: widgetH = 100
            }
            
            currentRowMax = max(currentRowMax, widgetH)
            
            if widgets.count > 1 {
                if (index + 1) % 2 == 0 || index == widgets.count - 1 {
                    rowHeights.append(currentRowMax)
                    currentRowMax = 0
                }
            } else {
                rowHeights.append(widgetH)
            }
        }
        
        let totalContentH = rowHeights.reduce(0, +) + CGFloat(max(0, rowHeights.count - 1)) * 16
        return totalContentH + notchHeight + 20
    }
    
    var currentSize: CGSize {
        let w = isExpanded ? expandedWidth : collapsedWidth
        let collapsedH = (isShowingBanner || isShowingLyricBanner) ? (notchHeight + bannerHeightAddon) : notchHeight
        let h = isExpanded ? expandedHeight : collapsedH
        return CGSize(width: w, height: h)
    }
    
    var body: some View {
        let hasMedia = nowPlaying.currentSong != "No Music" && nowPlaying.currentSong != "NOT_PLAYING"
        let size = currentSize
        
        ZStack(alignment: .top) {
            // 1. BACKGROUND (Dynamic Size)
            backgroundLayer(currentWidth: size.width, currentHeight: size.height)
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: size) // ⚡️ SMOOTH RESIZE
            
            // 2. COLLAPSED CONTENT
            collapsedLayer(hasMedia: hasMedia, currentCollapsedHeight: (isShowingBanner || isShowingLyricBanner) ? (notchHeight + bannerHeightAddon) : notchHeight)
                .opacity(isExpanded ? 0 : 1)
                .scaleEffect(isExpanded ? 0.95 : 1.0, anchor: .top)
                .allowsHitTesting(!isExpanded)
            
            // 3. EXPANDED CONTENT
            expandedLayer(expandedHeight: expandedHeight)
                .opacity(isExpanded ? 1 : 0)
                .scaleEffect(isExpanded ? 1.0 : 0.95, anchor: .top)
                .allowsHitTesting(isExpanded)
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: expandedHeight) // ⚡️ SMOOTH HEIGHT
            
            // 4. SETTINGS ICON
            if isExpanded && showSettingsButton {
                HStack {
                    Spacer()
                    Button(action: { SettingsWindowManager.shared.showSettings() }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.4))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(width: 28, height: 28)
                }
                .padding(.trailing, 20)
                .padding(.top, notchHeight + 6)
                .zIndex(5)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .contentShape(Rectangle())
        .onChange(of: size) { _, newSize in
            NotificationCenter.default.post(name: NSNotification.Name("UpdateNotchPosition"), object: newSize)
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                if !isExpanded && enableHoverToExpand {
                    if hoverTask == nil {
                        hoverTask = Task {
                            if hoverDelay > 0 {
                                try? await Task.sleep(nanoseconds: UInt64(hoverDelay * 1_000_000_000))
                            }
                            guard !Task.isCancelled else { return }
                            await MainActor.run {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.75, blendDuration: 0.1)) {
                                    isExpanded = true
                                    isShowingBanner = false
                                    isShowingLyricBanner = false
                                    bannerTask?.cancel()
                                    dashboardManager.refreshAvailableWidgets()
                                }
                            }
                        }
                    }
                }
            case .ended:
                hoverTask?.cancel()
                hoverTask = nil
                if isExpanded {
                    withAnimation(.spring(response: 0.30, dampingFraction: 1.0, blendDuration: 0.1)) {
                        isExpanded = false
                    }
                }
            }
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
        .animation(.spring(response: 0.35, dampingFraction: 0.75, blendDuration: 0.1), value: isExpanded)
        .animation(.spring(response: 0.30, dampingFraction: 1.0, blendDuration: 0.1), value: isShowingBanner || isShowingLyricBanner)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .edgesIgnoringSafeArea(.all)
        .opacity(isAppHidden ? 0 : 1)
        .allowsHitTesting(!isAppHidden)
        .onAppear {
            calendarManager.fetchTodaysEvents()
            KeyboardShortcuts.onKeyDown(for: .toggleAppVisibility) { isAppHidden.toggle() }
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
    }
    
    @ViewBuilder
    private func backgroundLayer(currentWidth: CGFloat, currentHeight: CGFloat) -> some View {
        DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: 16)
            .fill(Color.black)
            .shadow(color: Color.black.opacity(0.5), radius: 12, y: 6)
            .frame(width: currentWidth, height: currentHeight)
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
            )
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
            
            if (isShowingBanner || isShowingLyricBanner) && hasMedia {
                MarqueeText(text: isShowingBanner ? bannerText : currentLyricText, font: .system(size: 12, weight: .bold), alignment: .center)
                    .foregroundColor(nowPlaying.artworkDominantColor)
                    .frame(height: bannerHeightAddon)
                    .padding(.horizontal, 24)
            }
        }
        .frame(width: collapsedWidth, height: currentCollapsedHeight, alignment: .top)
        .onTapGesture { if !isExpanded { withAnimation { isExpanded = true } } }
        .zIndex(2)
    }
    
    @ViewBuilder
    private func expandedLayer(expandedHeight: CGFloat) -> some View {
        ExpandedDashboardView(
            nowPlaying: nowPlaying,
            calendarManager: calendarManager,
            expandedWidth: expandedWidth,
            skipDirection: $skipDirection,
            glowOpacity: $glowOpacity,
            onSwipe: { self.executeSkip(forward: $0) }
        )
        .padding(.top, notchHeight + 12)
        .frame(width: expandedWidth, height: expandedHeight, alignment: .top)
        .zIndex(3)
    }
    
    private func executeSkip(forward: Bool) {
        skipDirection = forward ? 1 : -1
        simulateMediaKey(keyCode: forward ? 20 : 19)
        triggerBanner(text: forward ? "Skipped Forward" : "Skipped Back", duration: 1.5)
    }
    
    private func handleSystemKey(event: NSEvent) {
        if event.subtype.rawValue == 8 {
            let data = event.data1
            let keyCode = (data & 0xFFFF0000) >> 16
            if keyCode == 19 { skipDirection = -1 } else if keyCode == 20 { skipDirection = 1 }
        }
    }
    
    private func handleScroll(event: NSEvent) {
        guard nowPlaying.currentSong != "No Music", abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY), Date().timeIntervalSince(lastSwipeTime) > 0.6 else { return }
        if event.scrollingDeltaX > 15 { executeSkip(forward: invertSwipeDirection); lastSwipeTime = Date() }
        else if event.scrollingDeltaX < -15 { executeSkip(forward: !invertSwipeDirection); lastSwipeTime = Date() }
    }
    
    private func updateLyricBanner() {
        guard showBannerLyrics, !isExpanded, nowPlaying.isPlaying, !nowPlaying.lyrics.isEmpty else {
            withAnimation { isShowingLyricBanner = false }; return
        }
        let newLyric = nowPlaying.lyrics[nowPlaying.activeLyricIndex].text
        if newLyric.isEmpty { withAnimation { isShowingLyricBanner = false } }
        else { withAnimation { currentLyricText = newLyric; isShowingLyricBanner = true } }
    }
    
    private func triggerBanner(text: String, duration: Double) {
        if !isExpanded {
            bannerText = text
            withAnimation { isShowingBanner = true }
            bannerTask?.cancel()
            bannerTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await MainActor.run { withAnimation { isShowingBanner = false }; updateLyricBanner() }
            }
        }
    }
    
    private func simulateMediaKey(keyCode: Int32) {
        func postKey(down: Bool) {
            let flags: NSEvent.ModifierFlags = down ? NSEvent.ModifierFlags(rawValue: 0xa00) : NSEvent.ModifierFlags(rawValue: 0xb00)
            let data1 = Int((keyCode << 16) | (down ? 0xa00 : 0xb00))
            NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: data1, data2: -1)?.cgEvent?.post(tap: .cghidEventTap)
        }
        postKey(down: true); postKey(down: false)
    }
}

// ---------------------------------------------------------
// ⚡️ CUSTOM PAN & ROTATE TRANSITIONS
// ---------------------------------------------------------
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
