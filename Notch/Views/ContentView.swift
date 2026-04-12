import SwiftUI
import AppKit
import Combine

enum AppTab {
    case player
    case playlist
}

struct ContentView: View {
    @State private var isExpanded = false
    @StateObject private var nowPlaying = NowPlayingManager()
    @State private var currentTab: AppTab = .player
    
    // ⚡️ USER SETTINGS
    @AppStorage("collapsedWidth") var storedCollapsedWidth: Double = 300.0 // NEW!
    
    @AppStorage("showBannerOnControl") var showBannerOnControl = true
    @AppStorage("bannerDuration") var bannerDuration: Double = 3.5
    @AppStorage("showLyrics") var showLyrics = true
    @AppStorage("showBannerLyrics") var showBannerLyrics = true
    @AppStorage("showGlowEffect") var showGlowEffect = true
    
    @AppStorage("visibleLyricLines") var visibleLyricLines = 3
    @AppStorage("invertSwipeDirection") var invertSwipeDirection = true
    
    @AppStorage("enableAppleMusic") var enableAppleMusic = false
    @AppStorage("enableSpotify") var enableSpotify = false
    @AppStorage("enableChrome") var enableChrome = false
    @AppStorage("enableBrave") var enableBrave = false
    @AppStorage("enableEdge") var enableEdge = false
    @AppStorage("enableSafari") var enableSafari = false
    
    // ⚡️ BANNER STATE
    @State private var isShowingBanner = false
    @State private var bannerText: String = ""
    @State private var bannerTask: Task<Void, Never>? = nil
    
    // ⚡️ LYRICS STATE
    @State private var isShowingLyricBanner = false
    @State private var currentLyricText: String = ""
    
    // ⚡️ GESTURE & ANIMATION STATE
    @State private var lastSwipeTime: Date = Date()
    @State private var localEventMonitor: Any?
    @State private var globalEventMonitor: Any?
    
    // ⚡️ RACING BORDER GLOW STATE
    @State private var glowRotation: Double = 0.0
    @State private var glowOpacity: Double = 0.0
    
    // ⚡️ HARDWARE KEYBOARD STATE
    @State private var localMediaKeyMonitor: Any?
    @State private var globalMediaKeyMonitor: Any?
    
    @State private var skipDirection: Int = 1
    @State private var lastSongChangeTime: Date = Date.distantPast
    
    let lyricTimer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    
    let notchHeight: CGFloat = 32
    let bannerHeightAddon: CGFloat = 24
    let expandedWidth: CGFloat = 400
    
    // ⚡️ THE FIX: Dynamically computed width from settings!
    var collapsedWidth: CGFloat { CGFloat(storedCollapsedWidth) }
    
    var body: some View {
        let hasMedia = nowPlaying.currentSong != "No Music" && nowPlaying.currentSong != "NOT_PLAYING"
        
        let basePlayerHeight: CGFloat = 132
        let dynamicLyricsHeight: CGFloat = CGFloat(visibleLyricLines) * 26.0
        let playerHeight: CGFloat = (!nowPlaying.lyrics.isEmpty && showLyrics) ? (basePlayerHeight + dynamicLyricsHeight + 12) : basePlayerHeight
        
        let expandedHeight: CGFloat = currentTab == .playlist ? 216 : playerHeight
        let currentWidth: CGFloat = isExpanded ? expandedWidth : collapsedWidth
        let currentCollapsedHeight: CGFloat = (isShowingBanner || isShowingLyricBanner) ? (notchHeight + bannerHeightAddon) : notchHeight
        let currentHeight: CGFloat = isExpanded ? expandedHeight : currentCollapsedHeight
        
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                backgroundLayer(currentWidth: currentWidth, currentHeight: currentHeight)
                collapsedLayer(hasMedia: hasMedia, currentCollapsedHeight: currentCollapsedHeight)
                expandedLayer(expandedHeight: expandedHeight)
            }
            .contentShape(DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: 16))
            .contextMenu {
                Button(action: { SettingsWindowManager.shared.showSettings() }) {
                    Text("Settings...")
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
                ? .spring(response: 0.35, dampingFraction: 0.72, blendDuration: 0.1)
                : .spring(response: 0.35, dampingFraction: 1.0, blendDuration: 0.1),
                value: isExpanded
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.8, blendDuration: 0.1), value: isShowingBanner || isShowingLyricBanner)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        
        // ⚡️ EVENT MONITORS
        .onAppear {
            let hasAnyAccess = enableAppleMusic || enableSpotify || enableChrome || enableBrave || enableEdge || enableSafari
            if !hasAnyAccess {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    SettingsWindowManager.shared.showSettings()
                    isExpanded = true
                }
            }
            
            localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                handleScroll(event: event)
                return event
            }
            globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { event in
                handleScroll(event: event)
            }
            localMediaKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .systemDefined) { event in
                handleSystemKey(event: event)
                return event
            }
            globalMediaKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { event in
                handleSystemKey(event: event)
            }
        }
        .onDisappear {
            if let local = localEventMonitor { NSEvent.removeMonitor(local) }
            if let global = globalEventMonitor { NSEvent.removeMonitor(global) }
            if let keyLocal = localMediaKeyMonitor { NSEvent.removeMonitor(keyLocal) }
            if let keyGlobal = globalMediaKeyMonitor { NSEvent.removeMonitor(keyGlobal) }
        }
        
        // ⚡️ GESTURES & HOVERS
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    guard hasMedia else { return }
                    if value.translation.width > 30 {
                        executeSkip(forward: invertSwipeDirection ? false : true)
                    } else if value.translation.width < -30 {
                        executeSkip(forward: invertSwipeDirection ? true : false)
                    }
                }
        )
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                let collapsedRect = CGRect(x: (400 - collapsedWidth) / 2, y: 0, width: collapsedWidth, height: currentCollapsedHeight)
                let expandedRect = CGRect(x: (400 - expandedWidth) / 2, y: 0, width: expandedWidth, height: expandedHeight)
                let targetRect = isExpanded ? expandedRect : collapsedRect
                
                if targetRect.contains(location) {
                    if !isExpanded {
                        isExpanded = true
                        isShowingBanner = false
                        isShowingLyricBanner = false
                        bannerTask?.cancel()
                    }
                } else {
                    if isExpanded { isExpanded = false }
                }
            case .ended:
                if isExpanded { isExpanded = false }
            }
        }
        
        // ⚡️ STATE OBSERVERS
        .onChange(of: isExpanded) { _, expanded in
            if !expanded {
                updateLyricBanner()
                currentTab = .player
            }
        }
        .onChange(of: nowPlaying.activeLyricIndex) { _, _ in updateLyricBanner() }
        .onChange(of: showBannerLyrics) { _, _ in updateLyricBanner() }
        .onReceive(lyricTimer) { _ in
            if nowPlaying.isPlaying && showBannerLyrics && !isExpanded { nowPlaying.updateActiveLyric() }
        }
        .onChange(of: nowPlaying.lyrics) { oldLyrics, newLyrics in updateLyricBanner() }
        .onChange(of: nowPlaying.currentSong) { oldSong, newSong in
            guard newSong != "No Music" && newSong != "NOT_PLAYING" else { return }
            lastSongChangeTime = Date()
            
            if showGlowEffect {
                glowOpacity = 0.0
                glowRotation = 0.0
                
                withAnimation(.easeIn(duration: 1.2)) { glowOpacity = 1.0 }
                withAnimation(.easeInOut(duration: 5.0)) { glowRotation = 360 }
                withAnimation(.easeOut(duration: 2.0).delay(3.0)) { glowOpacity = 0.0 }
            }
            
            triggerBanner(text: newSong, duration: bannerDuration)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { skipDirection = 1 }
        }
        .onChange(of: nowPlaying.isPlaying) { oldState, newState in
            updateLyricBanner()
            guard showBannerOnControl else { return }
            guard hasMedia else { return }
            guard Date().timeIntervalSince(lastSongChangeTime) > 0.5 else { return }
            triggerBanner(text: newState ? "Resumed" : "Paused", duration: 1.5)
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    // ---------------------------------------------------------
    // 💎 LAYER 1: THE SOLID BLACK NOTCH
    // ---------------------------------------------------------
    @ViewBuilder
    private func backgroundLayer(currentWidth: CGFloat, currentHeight: CGFloat) -> some View {
        DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: 16)
            .fill(Color.black)
            .shadow(color: Color.black.opacity(0.5), radius: 12, y: 6)
            .frame(width: currentWidth, height: currentHeight)
            .overlay(
                DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: 16)
                    .stroke(
                        LinearGradient(colors: [Color.white.opacity(isExpanded ? 0.2 : 0.0), Color.clear], startPoint: .top, endPoint: .bottom),
                        lineWidth: 1.5
                    )
            )
            .overlay(
                DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: 16)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: nowPlaying.artworkDominantColor.opacity(0.1), location: 0.02),
                                .init(color: nowPlaying.artworkDominantColor, location: 0.1),
                                .init(color: .white, location: 0.12),
                                .init(color: .white, location: 0.13),
                                .init(color: .clear, location: 0.131),
                                .init(color: .clear, location: 1.0)
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
    
    // ---------------------------------------------------------
    // 🎵 LAYER 2: THE COLLAPSED CONTENT
    // ---------------------------------------------------------
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
                            .shadow(color: nowPlaying.artworkDominantColor.opacity(glowOpacity), radius: 6, x: 0, y: 0)
                            .id(nowPlaying.currentSong)
                            .transition(.panRotate(direction: skipDirection))
                    } else {
                        Image(systemName: "music.note")
                            .foregroundColor(nowPlaying.isPlaying ? .white : .gray)
                            .font(.system(size: 14, weight: .bold))
                            .id("placeholder")
                            .transition(.opacity)
                    }
                }
                .frame(width: 24, alignment: .leading)
                .animation(.spring(response: 1.5, dampingFraction: 0.82), value: nowPlaying.currentSong)
                
                Spacer()
                
                WaveformView(isPlaying: nowPlaying.isPlaying, color: nowPlaying.artworkDominantColor)
                    .frame(width: 24, alignment: .trailing)
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
                            .id(bannerText)
                    } else if isShowingLyricBanner {
                        MarqueeText(text: currentLyricText, font: .system(size: 12, weight: .bold), alignment: .center)
                            .id(currentLyricText)
                            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity.combined(with: .move(edge: .top))))
                            .foregroundColor(nowPlaying.artworkDominantColor)
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
        .blur(radius: isExpanded ? 5 : 0)
        .allowsHitTesting(!isExpanded)
        .zIndex(2)
    }
    
    // ---------------------------------------------------------
    // 🎧 LAYER 3: THE EXPANDED CONTENT
    // ---------------------------------------------------------
    @ViewBuilder
    private func expandedLayer(expandedHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            if currentTab == .player {
                PlayerTabView(nowPlaying: nowPlaying, expandedWidth: expandedWidth, skipDirection: $skipDirection, glowOpacity: $glowOpacity)
                    .padding(.bottom, 14)
            } else {
                PlaylistTabView(nowPlaying: nowPlaying)
                    .padding(.bottom, 14)
            }
        }
        .padding(.top, notchHeight + 12)
        .frame(width: expandedWidth, height: expandedHeight)
        .opacity(isExpanded ? 1 : 0)
        .scaleEffect(isExpanded ? 1.0 : 0.95, anchor: .top)
        .blur(radius: isExpanded ? 0 : 5)
        .allowsHitTesting(isExpanded)
        .zIndex(3)
    }
    
    // ---------------------------------------------------------
    // ⚡️ HELPER METHODS
    // ---------------------------------------------------------
    private func executeSkip(forward: Bool) {
        skipDirection = forward ? 1 : -1
        simulateMediaKey(keyCode: forward ? 20 : 19)
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
    
    private func handleScroll(event: NSEvent) {
        let hasMedia = nowPlaying.currentSong != "No Music" && nowPlaying.currentSong != "NOT_PLAYING"
        guard hasMedia else { return }
        
        guard let screen = NSScreen.main else { return }
        let mouseLoc = NSEvent.mouseLocation
        let panelRect = CGRect(x: (screen.frame.width - 400) / 2, y: screen.frame.height - 260, width: 400, height: 260)
        
        guard panelRect.contains(mouseLoc) else { return }
        guard abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) else { return }
        guard Date().timeIntervalSince(lastSwipeTime) > 0.6 else { return }
        
        if event.scrollingDeltaX > 15 {
            executeSkip(forward: invertSwipeDirection)
            lastSwipeTime = Date()
        } else if event.scrollingDeltaX < -15 {
            executeSkip(forward: !invertSwipeDirection)
            lastSwipeTime = Date()
        }
    }
    
    private func updateLyricBanner() {
        guard showBannerLyrics,
              !isExpanded,
              nowPlaying.isPlaying,
              !nowPlaying.lyrics.isEmpty,
              nowPlaying.activeLyricIndex >= 0,
              nowPlaying.activeLyricIndex < nowPlaying.lyrics.count else {
            withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) { isShowingLyricBanner = false }
            return
        }
        
        let newLyric = nowPlaying.lyrics[nowPlaying.activeLyricIndex].text
        if newLyric.trimmingCharacters(in: .whitespaces).isEmpty {
            withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) { isShowingLyricBanner = false }
        } else {
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
    
    private func simulateMediaKey(keyCode: Int32) {
        func postKey(down: Bool) {
            let flags: NSEvent.ModifierFlags = down ? NSEvent.ModifierFlags(rawValue: 0xa00) : NSEvent.ModifierFlags(rawValue: 0xb00)
            let data1 = Int((keyCode << 16) | (down ? 0xa00 : 0xb00))
            if let event = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: data1, data2: -1) {
                event.cgEvent?.post(tap: .cghidEventTap)
            }
        }
        postKey(down: true)
        postKey(down: false)
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
