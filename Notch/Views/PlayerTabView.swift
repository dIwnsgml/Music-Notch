import SwiftUI
import Combine
import ApplicationServices // ⚡️ Needed for the Accessibility check

struct PlayerTabView: View {
    @ObservedObject var nowPlaying: NowPlayingManager
    
    var expandedWidth: CGFloat
    var isCompact: Bool
    @Binding var skipDirection: Int
    @Binding var glowOpacity: Double
    let onSwipe: (Bool) -> Void // ⚡️ ADDED: Scoped skip trigger
    
    @AppStorage("showLyrics") var showLyrics = true
    @AppStorage("visibleLyricLines") var visibleLyricLines = 3
    @AppStorage("lyricDimming") var lyricDimming: Double = 0.3
    @AppStorage("lyricBlurAmount") var lyricBlurAmount: Double = 0.4
    @AppStorage("enableDoubleClickToOpen") var enableDoubleClickToOpen = true
    @AppStorage("invertSwipeDirection") var invertSwipeDirection = true
    
    @AppStorage("enableAppleMusic") var enableAppleMusic = false
    @AppStorage("enableSpotify") var enableSpotify = false
    @AppStorage("enableChrome") var enableChrome = false
    @AppStorage("enableBrave") var enableBrave = false
    @AppStorage("enableEdge") var enableEdge = false
    @AppStorage("enableSafari") var enableSafari = false
    
    @AppStorage("themeBackgroundType") var themeBackgroundType: String = "color"
    @AppStorage("themeGlassyWidgets") var themeGlassyWidgets: Bool = true
    
    @State private var isDragging = false
    @State private var dragProgress: Double = 0.0
    @State private var isMouseOver = false
    @State private var isLyricsHovering = false
    @State private var isLyricOffsetRailHovering = false
    @State private var lastSwipeTime: Date = Date()
    @State private var localEventMonitor: Any?
    
    let localTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        let hasAnyAccess = enableAppleMusic || enableSpotify || enableChrome || enableBrave || enableEdge || enableSafari
        let hasMedia = nowPlaying.currentSong != "No Music" && nowPlaying.currentSong != "NOT_PLAYING"
        
        let hPad: CGFloat = isCompact ? 10 : 14
        let playerPanelWidth: CGFloat = expandedWidth
        let artSize: CGFloat = isCompact ? 46 : 54
        
        VStack(spacing: 0) {
            if !hasAnyAccess {
                HStack(spacing: 16) {
                    // 1. Icon Badge (Left Side)
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color.orange, Color.red], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 44, height: 44)
                            .shadow(color: Color.orange.opacity(0.4), radius: 6, x: 0, y: 3)
                        
                        Image(systemName: "puzzlepiece.extension.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: -0.5, y: -0.5)
                    }
                    
                    // 2. Text & Button (Right Side)
                    VStack(alignment: .leading, spacing: 6) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Welcome to WaveNotch")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Enable a player or browser to begin.")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        
                        Button(action: {
                            SettingsWindowManager.shared.showSettings()
                        }) {
                            Text("Open Settings")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.white)
                                .clipShape(Capsule())
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                
            } else {
                VStack(spacing: 0) {
                    // 1. TOP ROW: Artwork + Title
                    HStack(alignment: .center, spacing: 12) {
                        ZStack {
                            if hasMedia && nowPlaying.artworkURL != nil {
                                AsyncImage(url: nowPlaying.artworkURL) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(nowPlaying.artworkDominantColor.opacity(0.18))
                                        .overlay(ProgressView().controlSize(.mini))
                                }
                                    .frame(width: artSize, height: artSize)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                                    .shadow(color: nowPlaying.artworkDominantColor.opacity(max(glowOpacity, 0.18)), radius: 12, x: 0, y: 4)
                                    .id(nowPlaying.currentSong)
                                    .transition(.dynamicPanRotate(direction: skipDirection))

                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                        )
                                    Image(systemName: "music.note")
                                        .foregroundColor(nowPlaying.isPlaying ? .white : .gray)
                                        .font(.system(size: 20, weight: .bold))
                                }
                                .frame(width: artSize, height: artSize)
                                .transition(.opacity)
                            }
                        }
                        .frame(width: artSize, height: artSize)
                        .animation(.spring(response: 0.5, dampingFraction: 0.72), value: nowPlaying.currentSong)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(hasMedia ? (nowPlaying.isPlaying ? "Now Playing" : "Paused") : "Waiting...")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(hasMedia ? nowPlaying.artworkDominantColor : .gray)
                                    .lineLimit(1)
                                    .padding(.horizontal, 7)
                                    .frame(height: 18)
                                    .background((hasMedia ? nowPlaying.artworkDominantColor : Color.white).opacity(0.10))
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                
                                lyricStatusControls(hasMedia: hasMedia)
                            }
                            
                            if hasMedia {
                                let songParts = nowPlaying.currentSong.components(separatedBy: " - ")
                                let titleText = songParts.first ?? nowPlaying.currentSong
                                let artistText = songParts.count > 1 ? songParts.dropFirst().joined(separator: " - ") : ""
                                
                                MarqueeText(text: titleText, font: .system(size: isCompact ? 15 : 17, weight: .bold), alignment: .leading)
                                    .frame(height: isCompact ? 19 : 22)
                                    .foregroundColor(.white)
                                    .id("title_" + titleText)
                                
                                if !artistText.isEmpty {
                                    MarqueeText(text: artistText, font: .system(size: isCompact ? 12 : 13, weight: .semibold), alignment: .leading)
                                        .frame(height: 16)
                                        .foregroundColor(.white.opacity(0.58))
                                        .id("artist_" + artistText)
                                }
                            } else {
                                MarqueeText(text: "Nothing playing", font: .system(size: isCompact ? 15 : 17, weight: .bold), alignment: .leading)
                                    .frame(height: 22)
                                    .foregroundColor(.white)
                                    .id("nothing_playing")
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if hasMedia && !isCompact {
                            Spacer()
                            mediaControls
                        }
                    }
                    .padding(.horizontal, hPad)
                    
                    // Stacking controls under title if space is constrained
                    if hasMedia && isCompact {
                        HStack {
                            Spacer()
                            mediaControls
                            Spacer()
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 4)
                    }
                    
                    // 2. THE PROGRESS BAR
                    if hasMedia {
                        HStack(spacing: 8) {
                            Text(formatTime(isDragging ? (dragProgress * nowPlaying.duration) : nowPlaying.currentTime))
                                .font(.system(size: 9, design: .monospaced))
                                .monospacedDigit()
                                .foregroundColor(.gray)
                                .frame(width: 28, alignment: .leading)
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.13))
                                        .frame(height: 7)
                                    
                                    let progressRatio = min(1.0, max(0.0, isDragging ? dragProgress : (nowPlaying.currentTime / nowPlaying.duration)))
                                    
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [nowPlaying.artworkDominantColor.opacity(0.75), nowPlaying.artworkDominantColor],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * CGFloat(progressRatio), height: 7)
                                        .shadow(color: nowPlaying.artworkDominantColor.opacity(0.4), radius: 4, x: 0, y: 0)
                                }
                                .gesture(DragGesture(minimumDistance: 0)
                                    .onChanged { v in
                                        guard ensurePermissions() else { return }
                                        isDragging = true
                                        dragProgress = min(max(0, v.location.x / geo.size.width), 0.99)
                                    }
                                    .onEnded { v in
                                        guard ensurePermissions() else { return }
                                        let dragRatio = min(max(0, v.location.x / geo.size.width), 0.99)
                                        nowPlaying.seek(to: dragRatio)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isDragging = false }
                                    }
                                )
                            }.frame(height: 7)
                            
                            let remaining = max(0, nowPlaying.duration - (isDragging ? (dragProgress * nowPlaying.duration) : nowPlaying.currentTime))
                            Text("-" + formatTime(remaining))
                                .font(.system(size: 9, design: .monospaced))
                                .monospacedDigit()
                                .foregroundColor(.gray)
                                .frame(width: 32, alignment: .trailing)
                        }
                        .padding(.horizontal, hPad)
                        .padding(.top, 8)
                    }
                    
                    // 3. LYRICS
                    if showLyrics && hasMedia && !nowPlaying.lyrics.isEmpty {
                        HStack(alignment: .center, spacing: 6) {
                            GeometryReader { geo in
                                let itemHeight: CGFloat = 26
                                let exactFrameHeight: CGFloat = CGFloat(visibleLyricLines) * itemHeight
                                let activeOffset = CGFloat(nowPlaying.activeLyricIndex) * itemHeight
                                let centerAdjustment = (exactFrameHeight - itemHeight) / 2.0

                                VStack(spacing: 0) {
                                    ForEach(Array(nowPlaying.lyrics.enumerated()), id: \.offset) { index, lyric in
                                        let distance = abs(index - nowPlaying.activeLyricIndex)
                                        let lyricOpacity: Double = distance == 0 ? 1.0 : max(0.0, 1.0 - (Double(distance) * lyricDimming))
                                        let lyricScale: CGFloat = distance == 0 ? 1.0 : 1.0 - (CGFloat(distance) * 0.05)
                                        let lyricBlur: CGFloat = distance == 0 ? 0.0 : CGFloat(distance) * lyricBlurAmount

                                        Text(lyric.text)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.white.opacity(lyricOpacity))
                                            .multilineTextAlignment(.center)
                                            .frame(maxWidth: geo.size.width, alignment: .center)
                                            .frame(height: itemHeight)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                            .scaleEffect(lyricScale)
                                            .blur(radius: lyricBlur)
                                    }
                                }
                                .frame(width: geo.size.width, alignment: .center)
                                .offset(y: -activeOffset + centerAdjustment)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: nowPlaying.activeLyricIndex)
                            }
                            .frame(height: CGFloat(visibleLyricLines) * 26.0)
                            .clipped()
                            .mask(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: visibleLyricLines == 1 ? .black : .clear, location: 0),
                                        .init(color: .black, location: visibleLyricLines == 1 ? 0 : 0.05),
                                        .init(color: .black, location: visibleLyricLines == 1 ? 1 : 0.95),
                                        .init(color: visibleLyricLines == 1 ? .black : .clear, location: 1)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .contentShape(Rectangle())
                            .onHover { hovering in
                                withAnimation(.easeInOut(duration: 0.16)) {
                                    isLyricsHovering = hovering
                                }
                            }

                            ZStack {
                                if shouldShowLyricControls {
                                    lyricOffsetRail
                                        .transition(.opacity)
                                }
                            }
                            .frame(width: 32)
                        }
                        .padding(.horizontal, hPad)
                        .frame(height: CGFloat(visibleLyricLines) * 26.0)
                        .padding(.top, 8)
                    }
                }
                .frame(width: playerPanelWidth)
                .contentShape(Rectangle())
                .onHover { isMouseOver = $0 }
                .onAppear {
                    localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                        handleScroll(event: event)
                        return event
                    }
                }
                .onDisappear {
                    if let monitor = localEventMonitor {
                        NSEvent.removeMonitor(monitor)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 30)
                        .onEnded { value in
                            guard hasMedia else { return }
                            if value.translation.width > 30 {
                                onSwipe(false)
                            } else if value.translation.width < -30 {
                                onSwipe(true)
                            }
                        }
                )
                .onTapGesture(count: 2) {
                    if hasMedia && enableDoubleClickToOpen {
                        nowPlaying.openPlayingApp()
                    }
                }
                .padding(.top, 12)
            }
        }
        .padding(.bottom, 12)
        .frame(maxHeight: .infinity)
        .background(
            Group {
                if themeBackgroundType == "image" && themeGlassyWidgets {
                    if #available(macOS 26.0, *) {
                        Color.clear.glassEffect(in: .rect(cornerRadius: 16))
                    } else {
                        ZStack {
                            VisualEffectView(material: .popover, blendingMode: .withinWindow, alpha: 0.5)
                            LinearGradient(colors: [Color.white.opacity(0.15), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                        }
                    }
                }
            }
        )
        .cornerRadius(16)
        .overlay(
            Group {
                if themeBackgroundType == "image" && themeGlassyWidgets {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                }
            }
        )
        .onReceive(localTimer) { _ in
            if nowPlaying.isPlaying && !isDragging {
                nowPlaying.currentTime += 0.1
                nowPlaying.updateActiveLyric()
            }
        }
    }
    
    // ---------------------------------------------------------
    // ⚡️ HELPER METHODS
    // ---------------------------------------------------------

    private var shouldShowLyricControls: Bool {
        showLyrics && (isLyricsHovering || isLyricOffsetRailHovering)
    }

    private func lyricStatusControls(hasMedia: Bool) -> some View {
        HStack(spacing: 4) {
            if nowPlaying.isSearchingLyrics && showLyrics {
                ProgressView()
                    .controlSize(.mini)
                    .frame(width: 14, height: 14)
            }

            if hasMedia && showLyrics && nowPlaying.lyricsDisabledForCurrentSong {
                Button {
                    nowPlaying.toggleNoLyricsForCurrentSong()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 8, weight: .bold))
                        Text("No Lyrics")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.white.opacity(0.58))
                    .padding(.horizontal, 6)
                    .frame(height: 16)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
                .help("Search lyrics again")
            }

            if hasMedia && showLyrics && isMouseOver {
                lyricToolButton(systemName: "magnifyingglass", help: "Search lyrics manually") {
                    nowPlaying.promptForLyricsSearch()
                }

                lyricToolButton(
                    systemName: nowPlaying.lyricsDisabledForCurrentSong ? "arrow.clockwise" : "eye.slash.fill",
                    help: nowPlaying.lyricsDisabledForCurrentSong ? "Search lyrics again" : "Do not search lyrics for this song"
                ) {
                    nowPlaying.toggleNoLyricsForCurrentSong()
                }
            }
        }
        .frame(height: 18)
        .animation(.easeInOut(duration: 0.16), value: shouldShowLyricControls)
        .animation(.easeInOut(duration: 0.16), value: nowPlaying.lyricsDisabledForCurrentSong)
    }

    private var lyricOffsetRail: some View {
        VStack(spacing: 2) {
            lyricToolButton(systemName: "chevron.up", help: "Lyrics earlier") {
                nowPlaying.adjustCurrentSongLyricOffset(by: 0.5)
            }

            Text(formatCompactOffset(nowPlaying.currentSongLyricOffset))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.80))
                .frame(width: 30, height: 16)

            lyricToolButton(systemName: "chevron.down", help: "Lyrics later") {
                nowPlaying.adjustCurrentSongLyricOffset(by: -0.5)
            }
        }
        .padding(.vertical, 4)
        .frame(width: 32)
        .background(Color.black.opacity(0.30))
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(Capsule())
        .contentShape(Capsule())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.16)) {
                isLyricOffsetRailHovering = hovering
            }
        }
    }

    private func lyricToolButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.82))
                .frame(width: 18, height: 18)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func formatSignedOffset(_ value: Double) -> String {
        value == 0.0 ? "0.0s" : String(format: "%+.1fs", value)
    }

    private func formatCompactOffset(_ value: Double) -> String {
        value == 0.0 ? "0" : String(format: "%+.1f", value)
    }
    
    private func ensurePermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    private var mediaControls: some View {
        HStack(spacing: 12) {
            Button(action: {
                guard ensurePermissions() else { return }
                skipDirection = -1; nowPlaying.skipBackward()
            }) {
                ZStack { Image(systemName: "backward.fill").font(.system(size: 14)).foregroundColor(.white) }
                    .frame(width: 24, height: 24).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Button(action: {
                guard ensurePermissions() else { return }
                nowPlaying.togglePlayPause()
            }) {
                ZStack { Image(systemName: nowPlaying.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 16)).foregroundColor(.white) }
                    .frame(width: 24, height: 24).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Button(action: {
                guard ensurePermissions() else { return }
                skipDirection = 1; nowPlaying.skipForward()
            }) {
                ZStack { Image(systemName: "forward.fill").font(.system(size: 14)).foregroundColor(.white) }
                    .frame(width: 24, height: 24).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Button(action: {
                guard ensurePermissions() else { return }
                nowPlaying.toggleLoop()
            }) {
                ZStack { Image(systemName: nowPlaying.loopMode == 2 ? "repeat.1" : "repeat").font(.system(size: 14))
                    .foregroundColor(nowPlaying.loopMode > 0 ? .green : .white.opacity(0.6)) }
                .frame(width: 24, height: 24).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
    
    private func formatTime(_ s: Double) -> String {
        let safeSecs = max(0, s)
        if safeSecs.isNaN || safeSecs.isInfinite { return "0:00" }
        let ts = Int(safeSecs)
        return String(format: "%d:%02d", ts / 60, ts % 60)
    }
    
    private func handleScroll(event: NSEvent) {
        guard isMouseOver else { return }
        let hasMedia = nowPlaying.currentSong != "No Music" && nowPlaying.currentSong != "NOT_PLAYING"
        guard hasMedia else { return }
        
        guard abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) else { return }
        guard Date().timeIntervalSince(lastSwipeTime) > 0.6 else { return }
        
        if event.scrollingDeltaX > 15 {
            onSwipe(invertSwipeDirection ? false : true)
            lastSwipeTime = Date()
        } else if event.scrollingDeltaX < -15 {
            onSwipe(invertSwipeDirection ? true : false)
            lastSwipeTime = Date()
        }
    }
}
