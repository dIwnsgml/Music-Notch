import SwiftUI

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
    // Note: You can use @AppStorage("showLyrics") in your PlayerTabView to hide/show lyrics!
    
    // ⚡️ BANNER STATE
    @State private var isShowingBanner = false
    @State private var bannerText: String = "" // Holds the dynamic text
    @State private var bannerTask: Task<Void, Never>? = nil
    
    let notchHeight: CGFloat = 32
    let bannerHeightAddon: CGFloat = 24
    let collapsedWidth: CGFloat = 300
    let expandedWidth: CGFloat = 380

    var body: some View {
        let hasMedia = nowPlaying.currentSong != "No Music" && nowPlaying.currentSong != "NOT_PLAYING"
        let playerHeight: CGFloat = (!nowPlaying.lyrics.isEmpty && showLyrics) ? 164 : 100
                
        let expandedHeight: CGFloat = currentTab == .playlist ? 200 : playerHeight
        
        let currentWidth: CGFloat = isExpanded ? expandedWidth : collapsedWidth
        let currentCollapsedHeight: CGFloat = isShowingBanner ? (notchHeight + bannerHeightAddon) : notchHeight
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
                            
                            // ⚡️ DYNAMIC BANNER TEXT
                            if isShowingBanner && hasMedia {
                                MarqueeText(
                                    text: bannerText, // Uses our new state variable
                                    font: .system(size: 12, weight: .bold),
                                    alignment: .center
                                )
                                .foregroundColor(nowPlaying.artworkDominantColor)
                                .frame(height: bannerHeightAddon)
                                .padding(.horizontal, 24)
                                .transition(.opacity.combined(with: .move(edge: .top)))
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
            .animation(.spring(response: 0.3, dampingFraction: 1.0), value: isShowingBanner)
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
                        bannerTask?.cancel()
                    }
                } else {
                    if isExpanded { isExpanded = false }
                }
            case .ended:
                if isExpanded { isExpanded = false }
            }
        }
        // ⚡️ SONG CHANGE TRIGGER: Shows the song title for the user's preferred duration
        .onChange(of: nowPlaying.currentSong) { oldSong, newSong in
            guard newSong != "No Music" && newSong != "NOT_PLAYING" else { return }
            triggerBanner(text: newSong, duration: bannerDuration)
        }
        // ⚡️ PLAY/PAUSE TRIGGER: Shows a quick 1.5-second status update
        .onChange(of: nowPlaying.isPlaying) { oldState, newState in
            guard showBannerOnControl else { return }
            guard hasMedia else { return }
            
            let statusText = newState ? "Resumed" : "Paused"
            triggerBanner(text: statusText, duration: 1.5)
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    // ⚡️ THE UPGRADED BANNER ENGINE
    private func triggerBanner(text: String, duration: Double) {
        if !isExpanded {
            
            // Set the dynamic text before animating it down
            bannerText = text
            
            withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) {
                isShowingBanner = true
            }
            
            // Convert seconds to nanoseconds
            let sleepTime = UInt64(duration * 1_000_000_000)
            
            bannerTask?.cancel()
            bannerTask = Task {
                try? await Task.sleep(nanoseconds: sleepTime)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) {
                        isShowingBanner = false
                    }
                }
            }
        }
    }
}
