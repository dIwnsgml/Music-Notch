import SwiftUI
import Combine

struct PlayerTabView: View {
    @ObservedObject var nowPlaying: NowPlayingManager
    var expandedWidth: CGFloat
    
    @State private var isDragging = false
    @State private var dragProgress: Double = 0.0
    let localTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        let hasMedia = nowPlaying.currentSong != "No Music" && nowPlaying.currentSong != "NOT_PLAYING"
        
        VStack(spacing: 0) {
            HStack {
                Group {
                    if hasMedia && nowPlaying.artworkURL != nil {
                        AsyncImage(url: nowPlaying.artworkURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: { Color.gray.opacity(0.3) }
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        Image(systemName: "music.note")
                            .foregroundColor(nowPlaying.isPlaying ? Color.red : Color.gray)
                            .font(.system(size: 20, weight: .bold))
                    }
                }
                .transition(.scale.combined(with: .opacity))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(hasMedia ? (nowPlaying.isPlaying ? "Now Playing" : "Paused") : "Waiting...")
                        .font(.system(size: 11, weight: .semibold)).foregroundColor(.gray)
                    MarqueeText(
                        text: hasMedia ? nowPlaying.currentSong : "Nothing playing",
                        font: .system(size: 14, weight: .bold),
                        alignment: .leading
                    )
                    .foregroundColor(.white)
                }
                .padding(.leading, 6)
                
                Spacer()
                
                if hasMedia {
                    HStack(spacing: 4) {
                        Button(action: { nowPlaying.skipBackward() }) {
                            Image(systemName: "backward.fill")
                                .foregroundColor(.white).padding(8).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        
                        Button(action: { nowPlaying.togglePlayPause() }) {
                            Image(systemName: nowPlaying.isPlaying ? "pause.fill" : "play.fill")
                                .foregroundColor(.white).padding(8).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        
                        Button(action: { nowPlaying.skipForward() }) {
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
            
            if hasMedia && !nowPlaying.lyrics.isEmpty {
                GeometryReader { geo in
                    let itemHeight: CGFloat = 26
                    let activeOffset = CGFloat(nowPlaying.activeLyricIndex) * itemHeight
                    let centerAdjustment = (geo.size.height - itemHeight) / 2.0
                    
                    VStack(spacing: 0) {
                        ForEach(Array(nowPlaying.lyrics.enumerated()), id: \.offset) { index, lyric in
                            let distance = abs(index - nowPlaying.activeLyricIndex)
                            Text(lyric.text)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(distance == 0 ? .white : (distance == 1 ? .white.opacity(0.4) : .clear))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: expandedWidth - 48, alignment: .center)
                                .frame(height: itemHeight)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .scaleEffect(distance == 0 ? 1.0 : 0.85)
                                .blur(radius: distance == 0 ? 0 : 0.3)
                        }
                    }
                    .frame(width: geo.size.width, alignment: .center)
                    .offset(y: -activeOffset + centerAdjustment)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: nowPlaying.activeLyricIndex)
                }
                .frame(height: 52)
                .clipped()
                .mask(LinearGradient(gradient: Gradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.15), .init(color: .black, location: 0.85), .init(color: .clear, location: 1)]), startPoint: .top, endPoint: .bottom))
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
    
    private func formatTime(_ s: Double) -> String {
        let safeSecs = max(0, s)
        if safeSecs.isNaN || safeSecs.isInfinite { return "0:00" }
        let ts = Int(safeSecs)
        return String(format: "%d:%02d", ts / 60, ts % 60)
    }
}
