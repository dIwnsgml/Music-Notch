import SwiftUI
import Combine

struct PlayerTabView: View {
    @ObservedObject var nowPlaying: NowPlayingManager
    var expandedWidth: CGFloat
    
    @Binding var skipDirection: Int
    @Binding var glowOpacity: Double
    
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
            let hasMedia = nowPlaying.currentSong != "No Music" && nowPlaying.currentSong != "NOT_PLAYING"
            
            VStack(spacing: 0) {
                HStack {
                    ZStack {
                        if hasMedia && nowPlaying.artworkURL != nil {
                            AsyncImage(url: nowPlaying.artworkURL) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: { Color.gray.opacity(0.3) }
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .shadow(color: nowPlaying.artworkDominantColor.opacity(glowOpacity), radius: 10, x: 0, y: 0)
                                .id(nowPlaying.currentSong)
                                .transition(.dynamicPanRotate(direction: skipDirection))
                            
                        } else {
                            Image(systemName: "music.note")
                                .foregroundColor(nowPlaying.isPlaying ? Color.red : Color.gray)
                                .font(.system(size: 20, weight: .bold))
                                .id("placeholder")
                                .transition(.opacity)
                        }
                    }
                    .frame(width: 40, height: 40)
                    .animation(.spring(response: 0.5, dampingFraction: 0.72), value: nowPlaying.currentSong)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(hasMedia ? (nowPlaying.isPlaying ? "Now Playing" : "Paused") : "Waiting...")
                            .font(.system(size: 11, weight: .semibold)).foregroundColor(.gray)
                        MarqueeText(
                            text: hasMedia ? nowPlaying.currentSong : "Nothing playing",
                            font: .system(size: 14, weight: .bold),
                            alignment: .leading
                        )
                        .foregroundColor(.white)
                        .id(nowPlaying.currentSong)
                    }
                    .padding(.leading, 6)
                    
                    Spacer()
                    
                    if hasMedia {
                        HStack(spacing: 4) {
                            Button(action: {
                                skipDirection = -1
                                nowPlaying.skipBackward()
                            }) {
                                Image(systemName: "backward.fill")
                                    .foregroundColor(.white).padding(8).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            
                            Button(action: { nowPlaying.togglePlayPause() }) {
                                Image(systemName: nowPlaying.isPlaying ? "pause.fill" : "play.fill")
                                    .foregroundColor(.white).padding(8).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            
                            Button(action: {
                                skipDirection = 1
                                nowPlaying.skipForward()
                            }) {
                                Image(systemName: "forward.fill")
                                    .foregroundColor(.white).padding(8).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            
                            Button(action: { nowPlaying.toggleLoop() }) {
                                Image(systemName: nowPlaying.loopMode == 2 ? "repeat.1" : "repeat")
                                    .foregroundColor(nowPlaying.loopMode > 0 ? .green : .white.opacity(0.6))
                                    .padding(8).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 24)
                
                if hasMedia {
                    HStack(spacing: 8) {
                        Text(formatTime(isDragging ? (dragProgress * nowPlaying.duration) : nowPlaying.currentTime))
                            .font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
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
                                .onChanged { v in isDragging = true; dragProgress = min(max(0, v.location.x / geo.size.width), 0.99) }
                                .onEnded { v in
                                    let dragRatio = min(max(0, v.location.x / geo.size.width), 0.99)
                                    nowPlaying.seek(to: dragRatio)
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isDragging = false }
                                }
                            )
                        }.frame(height: 6)
                        
                        let remaining = max(0, nowPlaying.duration - (isDragging ? (dragProgress * nowPlaying.duration) : nowPlaying.currentTime))
                        Text("-" + formatTime(remaining))
                            .font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                }
                
                if showLyrics && hasMedia && !nowPlaying.lyrics.isEmpty {
                    GeometryReader { geo in
                        let itemHeight: CGFloat = 26
                        let exactFrameHeight: CGFloat = CGFloat(visibleLyricLines) * itemHeight
                        let activeOffset = CGFloat(nowPlaying.activeLyricIndex) * itemHeight
                        let centerAdjustment = (exactFrameHeight - itemHeight) / 2.0
                        
                        VStack(spacing: 0) {
                            ForEach(Array(nowPlaying.lyrics.enumerated()), id: \.offset) { index, lyric in
                                let distance = abs(index - nowPlaying.activeLyricIndex)
                                
                                // ⚡️ THE FIX: Smart Multiplier Math!
                                // The further away a line is, the more it multiplies the user's setting.
                                let lyricOpacity: Double = distance == 0 ? 1.0 : max(0.0, 1.0 - (Double(distance) * lyricDimming))
                                let lyricScale: CGFloat = distance == 0 ? 1.0 : 1.0 - (CGFloat(distance) * 0.05)
                                let lyricBlur: CGFloat = distance == 0 ? 0.0 : CGFloat(distance) * lyricBlurAmount
                                
                                Text(lyric.text)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white.opacity(lyricOpacity))
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: expandedWidth - 48, alignment: .center)
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
                    // ⚡️ THE FIX: Pushed the black gradient stops to 0.05 and 0.95 so it barely fades the edges
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
                    .padding(.top, 12)
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
    
    private func formatTime(_ s: Double) -> String {
        let safeSecs = max(0, s)
        if safeSecs.isNaN || safeSecs.isInfinite { return "0:00" }
        let ts = Int(safeSecs)
        return String(format: "%d:%02d", ts / 60, ts % 60)
    }
}
