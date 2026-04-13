import SwiftUI
import Combine
import EventKit
import ApplicationServices // ⚡️ Needed for the Accessibility check

struct PlayerTabView: View {
    @ObservedObject var nowPlaying: NowPlayingManager
    @ObservedObject var calendarManager: CalendarManager
    
    var expandedWidth: CGFloat
    @Binding var skipDirection: Int
    @Binding var glowOpacity: Double
    
    @AppStorage("enableCalendar") var enableCalendar = false
    @AppStorage("showLyrics") var showLyrics = true
    @AppStorage("visibleLyricLines") var visibleLyricLines = 3
    @AppStorage("lyricDimming") var lyricDimming: Double = 0.3
    @AppStorage("lyricBlurAmount") var lyricBlurAmount: Double = 0.4
    
    @AppStorage("enableAppleMusic") var enableAppleMusic = false
    @AppStorage("enableSpotify") var enableSpotify = false
    @AppStorage("enableChrome") var enableChrome = false
    @AppStorage("enableBrave") var enableBrave = false
    @AppStorage("enableEdge") var enableEdge = false
    @AppStorage("enableSafari") var enableSafari = false
    
    @State private var isDragging = false
    @State private var dragProgress: Double = 0.0
    let localTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        let hasAnyAccess = enableAppleMusic || enableSpotify || enableChrome || enableBrave || enableEdge || enableSafari
        let hasMedia = nowPlaying.currentSong != "No Music" && nowPlaying.currentSong != "NOT_PLAYING"
        let showSplitView = enableCalendar && calendarManager.hasAccess
        
        let hPad: CGFloat = showSplitView ? 20 : 36
        let calendarWidth: CGFloat = 170
        let playerPanelWidth: CGFloat = showSplitView ? (expandedWidth - calendarWidth) : expandedWidth
        
        if !hasAnyAccess {
            VStack(spacing: 8) {
                Image(systemName: "puzzlepiece.extension")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.orange)
                    .padding(.bottom, 2)
                
                Text("Setup Required")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Enable a browser or music player in settings.")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                Button(action: {
                    SettingsWindowManager.shared.showSettings()
                }) {
                    Text("Open Settings")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 16)
            
        } else {
            HStack(alignment: .top, spacing: 0) {
                
                // ==========================================
                // 🎵 LEFT SIDE: THE PLAYER
                // ==========================================
                VStack(spacing: 0) {
                    
                    // 1. TOP ROW: Artwork + Title
                    HStack(alignment: .center) {
                        ZStack {
                            if hasMedia && nowPlaying.artworkURL != nil {
                                Button(action: { nowPlaying.openPlayingApp() }) {
                                    AsyncImage(url: nowPlaying.artworkURL) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: { Color.gray.opacity(0.3) }
                                        .frame(width: 40, height: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .shadow(color: nowPlaying.artworkDominantColor.opacity(glowOpacity), radius: 10, x: 0, y: 0)
                                }
                                .buttonStyle(.plain)
                                .id(nowPlaying.currentSong)
                                .transition(.dynamicPanRotate(direction: skipDirection))
                                
                            } else {
                                Image(systemName: "music.note")
                                    .foregroundColor(nowPlaying.isPlaying ? Color.red : Color.gray)
                                    .font(.system(size: 20, weight: .bold))
                                    .transition(.opacity)
                            }
                        }
                        .frame(width: 40, height: 40)
                        .animation(.spring(response: 0.5, dampingFraction: 0.72), value: nowPlaying.currentSong)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(hasMedia ? (nowPlaying.isPlaying ? "Now Playing" : "Paused") : "Waiting...")
                                    .font(.system(size: 11, weight: .semibold)).foregroundColor(.gray)
                                
                                ZStack {
                                    if nowPlaying.isSearchingLyrics && showLyrics {
                                        ProgressView().controlSize(.mini)
                                    }
                                }
                                .frame(width: 14, height: 14)
                            }
                            
                            if hasMedia {
                                let songParts = nowPlaying.currentSong.components(separatedBy: " - ")
                                let titleText = songParts.first ?? nowPlaying.currentSong
                                let artistText = songParts.count > 1 ? songParts.dropFirst().joined(separator: " - ") : ""
                                
                                MarqueeText(text: titleText, font: .system(size: 14, weight: .bold), alignment: .leading)
                                    .frame(height: 18)
                                    .foregroundColor(.white)
                                    .id("title_" + titleText)
                                
                                if !artistText.isEmpty {
                                    MarqueeText(text: artistText, font: .system(size: 12, weight: .medium), alignment: .leading)
                                        .frame(height: 16)
                                        .foregroundColor(.white.opacity(0.6))
                                        .id("artist_" + artistText)
                                }
                            } else {
                                MarqueeText(text: "Nothing playing", font: .system(size: 14, weight: .bold), alignment: .leading)
                                    .frame(height: 18)
                                    .foregroundColor(.white)
                                    .id("nothing_playing")
                            }
                        }
                        .padding(.leading, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if hasMedia && !showSplitView {
                            Spacer()
                            mediaControls
                        }
                    }
                    .padding(.horizontal, hPad)
                    
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
                                    Capsule().fill(nowPlaying.artworkDominantColor.opacity(0.50)).frame(height: 6)
                                    
                                    let progressRatio = min(1.0, max(0.0, isDragging ? dragProgress : (nowPlaying.currentTime / nowPlaying.duration)))
                                    
                                    Capsule()
                                        .fill(nowPlaying.artworkDominantColor)
                                        .frame(width: geo.size.width * CGFloat(progressRatio), height: 6)
                                        .shadow(color: nowPlaying.artworkDominantColor.opacity(0.4), radius: 4, x: 0, y: 0)
                                }
                                .gesture(DragGesture(minimumDistance: 0)
                                    .onChanged { v in
                                        // ⚡️ THE FIX: Check permissions before allowing drag!
                                        guard ensurePermissions() else { return }
                                        isDragging = true
                                        dragProgress = min(max(0, v.location.x / geo.size.width), 0.99)
                                    }
                                    .onEnded { v in
                                        // ⚡️ THE FIX: Check permissions before skipping!
                                        guard ensurePermissions() else { return }
                                        let dragRatio = min(max(0, v.location.x / geo.size.width), 0.99)
                                        nowPlaying.seek(to: dragRatio)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isDragging = false }
                                    }
                                )
                            }.frame(height: 6)
                            
                            let remaining = max(0, nowPlaying.duration - (isDragging ? (dragProgress * nowPlaying.duration) : nowPlaying.currentTime))
                            Text("-" + formatTime(remaining))
                                .font(.system(size: 9, design: .monospaced))
                                .monospacedDigit()
                                .foregroundColor(.gray)
                                .frame(width: 32, alignment: .trailing)
                        }
                        .padding(.horizontal, hPad)
                        .padding(.top, 8)
                        
                        if showSplitView {
                            HStack {
                                Spacer()
                                mediaControls
                                Spacer()
                            }
                            .padding(.top, 12)
                            .padding(.bottom, 4)
                        }
                    }
                    
                    // 3. LYRICS
                    if showLyrics && hasMedia && !nowPlaying.lyrics.isEmpty {
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
                                        .frame(maxWidth: playerPanelWidth - (hPad * 2), alignment: .center)
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
                        .padding(.top, 8)
                    }
                }
                .frame(width: playerPanelWidth)
                
                // ==========================================
                // 📅 RIGHT SIDE: THE CALENDAR
                // ==========================================
                if showSplitView {
                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.vertical, 8)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.accentColor)
                            Text("Today")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 2)
                        
                        if calendarManager.todaysEvents.isEmpty {
                            Text("No upcoming events today.")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 16)
                        } else {
                            ScrollView(.vertical, showsIndicators: false) {
                                VStack(alignment: .leading, spacing: 10) {
                                    ForEach(calendarManager.todaysEvents, id: \.eventIdentifier) { event in
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(event.title)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                            
                                            Text(formatEventTime(event))
                                                .font(.system(size: 10))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .frame(width: calendarWidth - 1)
                    .padding(.top, 4)
                }
            }
            .onReceive(localTimer) { _ in
                if nowPlaying.isPlaying && !isDragging {
                    nowPlaying.currentTime += 0.1
                    nowPlaying.updateActiveLyric()
                }
            }
        }
    }
    
    // ---------------------------------------------------------
    // ⚡️ HELPER METHODS
    // ---------------------------------------------------------
    
    // ⚡️ THE FIX: A quick helper to pop the permission request!
    private func ensurePermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    private var mediaControls: some View {
        HStack(spacing: 12) {
            Button(action: {
                guard ensurePermissions() else { return } // ⚡️ Request on click
                skipDirection = -1; nowPlaying.skipBackward()
            }) {
                ZStack { Image(systemName: "backward.fill").font(.system(size: 14)).foregroundColor(.white) }
                    .frame(width: 24, height: 24).contentShape(Rectangle())
            }.buttonStyle(.plain)
            
            Button(action: {
                guard ensurePermissions() else { return } // ⚡️ Request on click
                nowPlaying.togglePlayPause()
            }) {
                ZStack { Image(systemName: nowPlaying.isPlaying ? "pause.fill" : "play.fill").font(.system(size: 16)).foregroundColor(.white) }
                    .frame(width: 24, height: 24).contentShape(Rectangle())
            }.buttonStyle(.plain)
            
            Button(action: {
                guard ensurePermissions() else { return } // ⚡️ Request on click
                skipDirection = 1; nowPlaying.skipForward()
            }) {
                ZStack { Image(systemName: "forward.fill").font(.system(size: 14)).foregroundColor(.white) }
                    .frame(width: 24, height: 24).contentShape(Rectangle())
            }.buttonStyle(.plain)
            
            Button(action: {
                guard ensurePermissions() else { return } // ⚡️ Request on click
                nowPlaying.toggleLoop()
            }) {
                ZStack { Image(systemName: nowPlaying.loopMode == 2 ? "repeat.1" : "repeat").font(.system(size: 14))
                    .foregroundColor(nowPlaying.loopMode > 0 ? .green : .white.opacity(0.6)) }
                .frame(width: 24, height: 24).contentShape(Rectangle())
            }.buttonStyle(.plain)
        }
    }
    
    private func formatTime(_ s: Double) -> String {
        let safeSecs = max(0, s)
        if safeSecs.isNaN || safeSecs.isInfinite { return "0:00" }
        let ts = Int(safeSecs)
        return String(format: "%d:%02d", ts / 60, ts % 60)
    }
    
    private func formatEventTime(_ event: EKEvent) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        if event.isAllDay { return "All Day" }
        return "\(formatter.string(from: event.startDate)) - \(formatter.string(from: event.endDate))"
    }
}
