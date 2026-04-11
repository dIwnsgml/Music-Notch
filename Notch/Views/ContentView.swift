import SwiftUI
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
    @AppStorage("showBannerOnControl") var showBannerOnControl = true
    @AppStorage("bannerDuration") var bannerDuration: Double = 3.5
    @AppStorage("showLyrics") var showLyrics = true
    
    // ⚡️ NEW: Setting to toggle continuous banner lyrics
    @AppStorage("showBannerLyrics") var showBannerLyrics = false
    
    // ⚡️ BANNER STATE (Dual-Layer System)
    @State private var isShowingBanner = false // Priority Layer (Play/Pause/Song Change)
    @State private var bannerText: String = ""
    @State private var bannerTask: Task<Void, Never>? = nil
    
    // ⚡️ NEW: Lyrics Layer State
    @State private var isShowingLyricBanner = false
    @State private var currentLyricText: String = ""
    
    // ⚡️ THE FIX: A persistent timer that never dies!
    let lyricTimer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    
    let notchHeight: CGFloat = 32
    let bannerHeightAddon: CGFloat = 24
    let collapsedWidth: CGFloat = 300
    let expandedWidth: CGFloat = 380

    var body: some View {
        let hasMedia = nowPlaying.currentSong != "No Music" && nowPlaying.currentSong != "NOT_PLAYING"
        let playerHeight: CGFloat = (!nowPlaying.lyrics.isEmpty && showLyrics) ? 164 : 100
                
        let expandedHeight: CGFloat = currentTab == .playlist ? 200 : playerHeight
        
        let currentWidth: CGFloat = isExpanded ? expandedWidth : collapsedWidth
        
        // ⚡️ FIX: The notch expands if EITHER the priority banner OR the lyric banner is active
        let currentCollapsedHeight: CGFloat = (isShowingBanner || isShowingLyricBanner) ? (notchHeight + bannerHeightAddon) : notchHeight
        let currentHeight: CGFloat = isExpanded ? expandedHeight : currentCollapsedHeight

        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                
                DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: 16)
                    .fill(Color.black)
                    .frame(width: currentWidth, height: currentHeight)
                    .overlay(
                        DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: 16)
                            .stroke(Color.white.opacity(isExpanded ? 0.1 : 0.0), lineWidth: 1)
                    )

                VStack(spacing: 0) {
                    if !isExpanded {
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
                            
                            // ⚡️ DYNAMIC DUAL-LAYER BANNER TEXT
                            // ⚡️ DYNAMIC DUAL-LAYER BANNER TEXT
                                                        let showAnyBanner = (isShowingBanner || isShowingLyricBanner) && hasMedia
                                                        
                                                        if showAnyBanner {
                                                            ZStack {
                                                                // LAYER 1: The Priority Banner (Play/Pause, Song Title)
                                                                // Drops from the top
                                                                if isShowingBanner {
                                                                    MarqueeText(
                                                                        text: bannerText,
                                                                        font: .system(size: 12, weight: .bold),
                                                                        alignment: .center
                                                                    )
                                                                    .foregroundColor(nowPlaying.artworkDominantColor)
                                                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                                                }
                                                                // LAYER 2: The Lyric Teleprompter
                                                                // Scrolls vertically from the bottom
                                                                else if isShowingLyricBanner {
                                                                    MarqueeText(
                                                                        text: currentLyricText,
                                                                        font: .system(size: 12, weight: .bold),
                                                                        alignment: .center
                                                                    )
                                                                    .id(currentLyricText) // ⚡️ Forces SwiftUI to treat this as a brand new line
                                                                    .transition(.asymmetric(
                                                                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                                                                        removal: .opacity.combined(with: .move(edge: .top))
                                                                    ))
                                                                    .foregroundColor(nowPlaying.artworkDominantColor)
                                                                }
                                                            }
                                                            .frame(height: bannerHeightAddon)
                                                            .padding(.horizontal, 24)
                                                            .clipped() // ⚡️ THE MAGIC MASK: Hides the text as it scrolls outside the 24px height!
                                                        }
                        }
                        .transition(.opacity)
                        
                    } else {
                        VStack(spacing: 8) {
                            HStack {
                                Button(action: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
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
                                    ProgressView()
                                        .controlSize(.small)
                                        .padding(.trailing, 4)
                                        .transition(.opacity)
                                }
                                
                                Button(action: {
                                    SettingsWindowManager.shared.showSettings()
                                }) {
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
                                    .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity.combined(with: .move(edge: .leading))))
                            } else {
                                PlaylistTabView(nowPlaying: nowPlaying)
                                    .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity.combined(with: .move(edge: .leading))))
                            }
                        }
                        .padding(.bottom, 8)
                        .transition(.opacity)
                    }
                }
                .frame(width: currentWidth, height: currentHeight)
            }
            .animation(.spring(response: 0.3, dampingFraction: 1.0), value: isShowingBanner || isShowingLyricBanner)
            .animation(isExpanded ? .spring(response: 0.4, dampingFraction: 0.7) : .spring(response: 0.3, dampingFraction: 1.0), value: isExpanded)
            
            Spacer()
        }
        .frame(width: expandedWidth, height: 200)
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                let collapsedRect = CGRect(x: (expandedWidth - collapsedWidth) / 2, y: 0, width: collapsedWidth, height: currentCollapsedHeight)
                let expandedRect = CGRect(x: 0, y: 0, width: expandedWidth, height: expandedHeight)
                
                let targetRect = isExpanded ? expandedRect : collapsedRect
                
                if targetRect.contains(location) {
                    if !isExpanded {
                        isExpanded = true
                        isShowingBanner = false
                        isShowingLyricBanner = false // ⚡️ Instantly hide lyrics when expanding
                        bannerTask?.cancel()
                    }
                } else {
                    if isExpanded { isExpanded = false }
                }
            case .ended:
                if isExpanded { isExpanded = false }
            }
        }
        // ⚡️ NEW: Re-check if we need to show lyrics when the notch collapses
        .onChange(of: isExpanded) { _, expanded in
            if !expanded { updateLyricBanner() }
        }
        // ⚡️ NEW: Update banner when a new lyric line hits
        .onChange(of: nowPlaying.activeLyricIndex) { _, _ in updateLyricBanner() }
        // ⚡️ NEW: Instantly show/hide if the user flips the setting toggle
        .onChange(of: showBannerLyrics) { _, _ in updateLyricBanner() }
        
        // ⚡️ THE FIX: Force the engine to check the lyrics 4 times a second, even when collapsed!
        .onReceive(lyricTimer) { _ in
            if nowPlaying.isPlaying && showBannerLyrics && !isExpanded {
                nowPlaying.updateActiveLyric()
            }
        }
        
        // ⚡️ Wakes the engine up the exact millisecond the lyrics finish downloading
        .onChange(of: nowPlaying.lyrics) { oldLyrics, newLyrics in
            updateLyricBanner()
        }
        
        .onChange(of: nowPlaying.currentSong) { oldSong, newSong in
            guard newSong != "No Music" && newSong != "NOT_PLAYING" else { return }
            triggerBanner(text: newSong, duration: bannerDuration)
        }
        .onChange(of: nowPlaying.isPlaying) { oldState, newState in
            guard showBannerOnControl else { return }
            guard hasMedia else { return }
            
            let statusText = newState ? "Resumed" : "Paused"
            triggerBanner(text: statusText, duration: 1.5)
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    // ⚡️ NEW: The Lyric Engine Controller
        private func updateLyricBanner() {
            // Safe checks: Only show if setting is ON, notch is collapsed, and we have valid lyrics
            guard showBannerLyrics,
                  !isExpanded,
                  !nowPlaying.lyrics.isEmpty,
                  nowPlaying.activeLyricIndex >= 0,
                  nowPlaying.activeLyricIndex < nowPlaying.lyrics.count else {
                withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) {
                    isShowingLyricBanner = false
                }
                return
            }
            
            let newLyric = nowPlaying.lyrics[nowPlaying.activeLyricIndex].text
            
            // Hide if the lyric line is completely empty (instrumental break)
            if newLyric.trimmingCharacters(in: .whitespaces).isEmpty {
                withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) {
                    isShowingLyricBanner = false
                }
            } else {
                // ⚡️ FIX: Assign the text INSIDE the animation block!
                // This guarantees the vertical scroll transition is triggered.
                withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                    currentLyricText = newLyric
                    isShowingLyricBanner = true
                }
            }
        }
    
    private func triggerBanner(text: String, duration: Double) {
        if !isExpanded {
            bannerText = text
            withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) {
                isShowingBanner = true
            }
            
            let sleepTime = UInt64(duration * 1_000_000_000)
            
            bannerTask?.cancel()
            bannerTask = Task {
                try? await Task.sleep(nanoseconds: sleepTime)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) {
                        isShowingBanner = false
                    }
                    // ⚡️ FIX 2: Explicitly tells the Lyric Engine it is allowed to take over now!
                    updateLyricBanner()
                }
            }
        }
    }
}
