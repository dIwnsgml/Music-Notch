import SwiftUI
import AppKit
import Combine // ⚡️ The crucial import for the lyric timer!

enum AppTab {
    case player
    case playlist
}

struct ContentView: View {
    @State private var isExpanded = false
    @StateObject private var nowPlaying = NowPlayingManager()
    @State private var currentTab: AppTab = .player
    
    // ⚡️ USER SETTINGS
    @AppStorage("showBannerOnControl") var showBannerOnControl = true
    @AppStorage("bannerDuration") var bannerDuration: Double = 3.5
    @AppStorage("showLyrics") var showLyrics = true
    @AppStorage("showBannerLyrics") var showBannerLyrics = false
    
    // ⚡️ BANNER STATE
    @State private var isShowingBanner = false
    @State private var bannerText: String = ""
    @State private var bannerTask: Task<Void, Never>? = nil
    
    // ⚡️ LYRICS STATE
    @State private var isShowingLyricBanner = false
    @State private var currentLyricText: String = ""
    
    // ⚡️ GESTURE STATE
    @State private var lastSwipeTime: Date = Date()
    @State private var localEventMonitor: Any?
    @State private var globalEventMonitor: Any?
    
    let lyricTimer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    
    let notchHeight: CGFloat = 32
    let bannerHeightAddon: CGFloat = 24
    let collapsedWidth: CGFloat = 300
    let expandedWidth: CGFloat = 380

    var body: some View {
        let hasMedia = nowPlaying.currentSong != "No Music" && nowPlaying.currentSong != "NOT_PLAYING"
        
        let playerHeight: CGFloat = (!nowPlaying.lyrics.isEmpty && showLyrics) ? 180 : 128
        let expandedHeight: CGFloat = currentTab == .playlist ? 216 : playerHeight
        
        let currentWidth: CGFloat = isExpanded ? expandedWidth : collapsedWidth
        let currentCollapsedHeight: CGFloat = (isShowingBanner || isShowingLyricBanner) ? (notchHeight + bannerHeightAddon) : notchHeight
        let currentHeight: CGFloat = isExpanded ? expandedHeight : currentCollapsedHeight

        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                
                // ---------------------------------------------------------
                // 💎 LAYER 1: THE SOLID BLACK NOTCH
                // ---------------------------------------------------------
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
                    .zIndex(1)

                // ---------------------------------------------------------
                // 🎵 LAYER 2: THE COLLAPSED CONTENT (Fades Out)
                // ---------------------------------------------------------
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Group {
                            if hasMedia && nowPlaying.artworkURL != nil {
                                AsyncImage(url: nowPlaying.artworkURL) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: { Color.gray.opacity(0.3) }
                                .frame(width: 20, height: 20)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            } else {
                                Image(systemName: "music.note")
                                    .foregroundColor(nowPlaying.isPlaying ? .white : .gray)
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                        .frame(width: 24, alignment: .leading)
                        
                        Spacer()
                        
                        WaveformView(isPlaying: nowPlaying.isPlaying, color: nowPlaying.artworkDominantColor)
                            .frame(width: 24, alignment: .trailing)
                    }
                    .padding(.horizontal, 24)
                    .frame(height: notchHeight)
                    
                    let showAnyBanner = (isShowingBanner || isShowingLyricBanner) && hasMedia
                    if showAnyBanner {
                        ZStack {
                            if isShowingBanner {
                                MarqueeText(text: bannerText, font: .system(size: 12, weight: .bold), alignment: .center)
                                    .foregroundColor(nowPlaying.artworkDominantColor)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
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

                // ---------------------------------------------------------
                // 🎧 LAYER 3: THE EXPANDED CONTENT (Fades In)
                // ---------------------------------------------------------
                VStack(spacing: 8) {
                    HStack {
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                currentTab = currentTab == .player ? .playlist : .player
                            }
                        }) {
                            Image(systemName: currentTab == .player ? "list.bullet" : "music.note")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(8)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                        
                        if nowPlaying.isSearchingLyrics && showLyrics {
                            ProgressView().controlSize(.small).padding(.trailing, 4)
                        }
                        
                        Button(action: { SettingsWindowManager.shared.showSettings() }) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                                .padding(8)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(height: notchHeight - 8)
                    .padding(.horizontal, 16)
                    
                    if currentTab == .player {
                        PlayerTabView(nowPlaying: nowPlaying, expandedWidth: expandedWidth)
                            .padding(.bottom, 16)
                    } else {
                        PlaylistTabView(nowPlaying: nowPlaying)
                            .padding(.bottom, 16)
                    }
                }
                .padding(.top, 6)
                .frame(width: expandedWidth, height: expandedHeight)
                .opacity(isExpanded ? 1 : 0)
                .scaleEffect(isExpanded ? 1.0 : 0.95, anchor: .top)
                .blur(radius: isExpanded ? 0 : 5)
                .allowsHitTesting(isExpanded)
                .zIndex(3)

            }
            .clipShape(DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: 16))
            .animation(.spring(response: 0.35, dampingFraction: 0.72, blendDuration: 0.1), value: isExpanded)
            .animation(.spring(response: 0.35, dampingFraction: 0.8, blendDuration: 0.1), value: isShowingBanner || isShowingLyricBanner)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        
        // ⚡️ THE SOLUTION: Wake up the Global Monitors!
        .onAppear {
            // Monitor when the app IS focused (Local)
            localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                handleScroll(event: event)
                return event
            }
            
            // Monitor when the app IS NOT focused (Global Background Hover)
            globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { event in
                handleScroll(event: event)
            }
        }
        .onDisappear {
            if let local = localEventMonitor { NSEvent.removeMonitor(local) }
            if let global = globalEventMonitor { NSEvent.removeMonitor(global) }
        }
        
        // Keeps the click-and-drag gesture intact for physical mouse users!
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    guard hasMedia else { return }
                    if value.translation.width < -30 {
                        simulateMediaKey(keyCode: 20)
                        triggerBanner(text: "Skipped Forward", duration: 1.5)
                    } else if value.translation.width > 30 {
                        simulateMediaKey(keyCode: 19)
                        triggerBanner(text: "Skipped Back", duration: 1.5)
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
        .onChange(of: isExpanded) { _, expanded in if !expanded { updateLyricBanner() } }
        .onChange(of: nowPlaying.activeLyricIndex) { _, _ in updateLyricBanner() }
        .onChange(of: showBannerLyrics) { _, _ in updateLyricBanner() }
        .onReceive(lyricTimer) { _ in
            if nowPlaying.isPlaying && showBannerLyrics && !isExpanded { nowPlaying.updateActiveLyric() }
        }
        .onChange(of: nowPlaying.lyrics) { oldLyrics, newLyrics in updateLyricBanner() }
        .onChange(of: nowPlaying.currentSong) { oldSong, newSong in
            guard newSong != "No Music" && newSong != "NOT_PLAYING" else { return }
            triggerBanner(text: newSong, duration: bannerDuration)
        }
        .onChange(of: nowPlaying.isPlaying) { oldState, newState in
            updateLyricBanner()
            guard showBannerOnControl else { return }
            guard hasMedia else { return }
            triggerBanner(text: newState ? "Resumed" : "Paused", duration: 1.5)
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    // ---------------------------------------------------------
    // ⚡️ HELPER METHODS
    // ---------------------------------------------------------
    
    // The Mathematical Trackpad Engine
    private func handleScroll(event: NSEvent) {
        let hasMedia = nowPlaying.currentSong != "No Music" && nowPlaying.currentSong != "NOT_PLAYING"
        guard hasMedia else { return }
        
        // 1. Check if the mouse is physically over our invisible 400x260 AppKit window
        guard let screen = NSScreen.main else { return }
        let mouseLoc = NSEvent.mouseLocation
        
        // Recreates the exact bounding box from your AppDelegate
        let panelRect = CGRect(
            x: (screen.frame.width - 400) / 2,
            y: screen.frame.height - 260,
            width: 400,
            height: 260
        )
        
        guard panelRect.contains(mouseLoc) else { return }
        
        // 2. Ensure it's a strong horizontal swipe, ignoring up/down scrolls
        guard abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) else { return }
        
        // 3. The Debounce: Prevents firing 50 times a second
        guard Date().timeIntervalSince(lastSwipeTime) > 0.6 else { return }
        
        if event.scrollingDeltaX > 15 {
            // Swipe Right
            simulateMediaKey(keyCode: 19)
            triggerBanner(text: "Skipped Back", duration: 1.5)
            lastSwipeTime = Date()
        } else if event.scrollingDeltaX < -15 {
            // Swipe Left
            simulateMediaKey(keyCode: 20)
            triggerBanner(text: "Skipped Forward", duration: 1.5)
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
            
            if let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            ) {
                event.cgEvent?.post(tap: .cghidEventTap)
            }
        }
        
        postKey(down: true)
        postKey(down: false)
    }
}
