import SwiftUI
import Combine
import AppKit

extension NSImage {
    var averageColor: Color {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return .green }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rgba = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(data: &rgba, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return .green }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        
        var r = CGFloat(rgba[0]) / 255.0
        var g = CGFloat(rgba[1]) / 255.0
        var b = CGFloat(rgba[2]) / 255.0
        let maxColor = max(r, max(g, b))
        if maxColor < 0.4 {
            let boost = 0.4 - maxColor
            r += boost; g += boost; b += boost
        }
        return Color(red: Double(r), green: Double(g), blue: Double(b))
    }
}

struct DynamicNotchShape: Shape {
    var cornerRadius: CGFloat
    var blendRadius: CGFloat = 16
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addQuadCurve(to: CGPoint(x: blendRadius, y: blendRadius), control: CGPoint(x: blendRadius, y: 0))
        path.addLine(to: CGPoint(x: blendRadius, y: rect.maxY - cornerRadius))
        path.addQuadCurve(to: CGPoint(x: blendRadius + cornerRadius, y: rect.maxY), control: CGPoint(x: blendRadius, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - blendRadius - cornerRadius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - blendRadius, y: rect.maxY - cornerRadius), control: CGPoint(x: rect.maxX - blendRadius, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - blendRadius, y: blendRadius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: 0), control: CGPoint(x: rect.maxX - blendRadius, y: 0))
        path.addLine(to: CGPoint(x: 0, y: 0))
        return path
    }
}

struct WaveformView: View {
    var isPlaying: Bool
    var color: Color
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<4) { index in
                Capsule()
                    .fill(isPlaying ? color : Color.gray.opacity(0.5))
                    .frame(width: 3, height: isPlaying ? (isAnimating ? .random(in: 6...14) : 4) : 4)
                    .animation(
                        isPlaying ? Animation.easeInOut(duration: 0.3).repeatForever().delay(Double(index) * 0.1) : .easeOut(duration: 0.2),
                        value: isAnimating
                    )
            }
        }
        .onChange(of: isPlaying) { playing in isAnimating = playing }
        .onAppear { if isPlaying { isAnimating = true } }
    }
}

struct MarqueeText: View {
    var text: String
    var font: Font
    var alignment: Alignment = .leading
    
    @State private var textWidth: CGFloat = 0
    @State private var isAnimating = false
    private let spacing: CGFloat = 30
    
    var body: some View {
        GeometryReader { proxy in
            let containerWidth = proxy.size.width
            
            if textWidth > containerWidth && containerWidth > 0 {
                HStack(spacing: spacing) {
                    Text(text).font(font).lineLimit(1).fixedSize()
                    Text(text).font(font).lineLimit(1).fixedSize()
                }
                .offset(x: isAnimating ? -(textWidth + spacing) : 0)
                .animation(
                    isAnimating ? .linear(duration: Double(textWidth) / 30.0).repeatForever(autoreverses: false) : .default,
                    value: isAnimating
                )
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        isAnimating = true
                    }
                }
            } else {
                Text(text)
                    .font(font)
                    .lineLimit(1)
                    .frame(width: containerWidth, alignment: alignment)
            }
        }
        .clipped()
        .id(text)
        .background(
            Text(text)
                .font(font)
                .lineLimit(1)
                .fixedSize()
                .background(GeometryReader { geo in
                    Color.clear
                        .onAppear { textWidth = geo.size.width }
                        .onChange(of: geo.size.width) { w in textWidth = w }
                })
                .hidden()
        )
    }
}

// ⚡️ 1. Track which tab is active
enum AppTab {
    case player
    case playlist
}

struct ContentView: View {
    @State private var isExpanded = false
    @StateObject private var nowPlaying = NowPlayingManager()
    
    // ⚡️ 2. State for the new tab switcher
    @State private var currentTab: AppTab = .player
    
    @State private var isDragging = false
    @State private var dragProgress: Double = 0.0
    let localTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    let notchHeight: CGFloat = 32
    let collapsedWidth: CGFloat = 300
    let expandedWidth: CGFloat = 380

    var body: some View {
        let hasMedia = nowPlaying.currentSong != "No Music" && nowPlaying.currentSong != "NOT_PLAYING"
        
        // ⚡️ 3. Dynamic height routing. Playlist gets a fixed 200px to give room for items.
        let playerHeight: CGFloat = !nowPlaying.lyrics.isEmpty ? 164 : 100
        let expandedHeight: CGFloat = currentTab == .playlist ? 200 : playerHeight

        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                
                DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: 16)
                    .fill(Color.black)
                    .frame(width: isExpanded ? expandedWidth : collapsedWidth,
                           height: isExpanded ? expandedHeight : notchHeight)
                    .overlay(
                        DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: 16)
                            .stroke(Color.white.opacity(isExpanded ? 0.1 : 0.0), lineWidth: 1)
                    )

                VStack(spacing: 0) {
                    if !isExpanded {
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
                        .transition(.opacity)
                        
                    } else {
                        VStack(spacing: 8) {
                            // ⚡️ 4. The Tab Switcher Button (Top Left)
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
                            }
                            .frame(height: notchHeight - 8)
                            .padding(.horizontal, 16)
                            
                            // ⚡️ 5. Content Router
                            if currentTab == .player {
                                // --- PLAYER TAB ---
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
                                                    .foregroundColor(.white)
                                                    .padding(8)
                                                    .contentShape(Rectangle())
                                            }
                                            .buttonStyle(.plain)
                                            
                                            Button(action: { nowPlaying.togglePlayPause() }) {
                                                Image(systemName: nowPlaying.isPlaying ? "pause.fill" : "play.fill")
                                                    .foregroundColor(.white)
                                                    .padding(8)
                                                    .contentShape(Rectangle())
                                            }
                                            .buttonStyle(.plain)
                                            
                                            Button(action: { nowPlaying.skipForward() }) {
                                                Image(systemName: "forward.fill")
                                                    .foregroundColor(.white)
                                                    .padding(8)
                                                    .contentShape(Rectangle())
                                            }
                                            .buttonStyle(.plain)
                                            
                                            Button(action: { nowPlaying.toggleLoop() }) {
                                                Image(systemName: nowPlaying.loopMode == 2 ? "repeat.1" : "repeat")
                                                    .foregroundColor(nowPlaying.loopMode > 0 ? .green : .white.opacity(0.6))
                                                    .padding(8)
                                                    .contentShape(Rectangle())
                                            }
                                            .buttonStyle(.plain)
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
                                    }.padding(.horizontal, 24)
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
                                }
                            } else {
                                                            // --- PLAYLIST TAB ---
                                                            VStack(spacing: 0) {
                                                                if nowPlaying.playlist.isEmpty {
                                                                    VStack {
                                                                        Image(systemName: "music.note.list")
                                                                            .font(.system(size: 24))
                                                                            .foregroundColor(.gray.opacity(0.6))
                                                                            .padding(.bottom, 4)
                                                                        Text("No upcoming tracks found")
                                                                            .font(.system(size: 12, weight: .semibold))
                                                                            .foregroundColor(.gray)
                                                                    }
                                                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                                                } else {
                                                                    ScrollView(showsIndicators: false) {
                                                                        VStack(alignment: .leading, spacing: 10) {
                                                                            ForEach(nowPlaying.playlist) { track in
                                                                                Button(action: {
                                                                                    nowPlaying.playTrack(track)
                                                                                }) {
                                                                                    HStack(spacing: 12) {
                                                                                        Group {
                                                                                            if let urlString = track.imageURL, let url = URL(string: urlString), urlString != "NO_IMAGE", !urlString.isEmpty {
                                                                                                AsyncImage(url: url) { image in
                                                                                                    image.resizable().aspectRatio(contentMode: .fill)
                                                                                                } placeholder: {
                                                                                                    Rectangle().fill(nowPlaying.artworkDominantColor.opacity(0.3))
                                                                                                }
                                                                                            } else {
                                                                                                ZStack {
                                                                                                    Rectangle().fill(nowPlaying.artworkDominantColor.opacity(0.3))
                                                                                                    Image(systemName: "music.note")
                                                                                                        .font(.system(size: 10, weight: .bold))
                                                                                                        .foregroundColor(.white.opacity(0.8))
                                                                                                }
                                                                                            }
                                                                                        }
                                                                                        .frame(width: 32, height: 32)
                                                                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                                                                        
                                                                                        VStack(alignment: .leading, spacing: 2) {
                                                                                            // Highlight the currently playing track
                                                                                            let isCurrent = nowPlaying.currentSong.contains(track.title)
                                                                                            
                                                                                            Text(track.title)
                                                                                                .font(.system(size: 12, weight: .bold))
                                                                                                .foregroundColor(isCurrent ? nowPlaying.artworkDominantColor : .white)
                                                                                                .lineLimit(1)
                                                                                            
                                                                                            Text(track.artist)
                                                                                                .font(.system(size: 10, weight: .medium))
                                                                                                .foregroundColor(isCurrent ? nowPlaying.artworkDominantColor.opacity(0.8) : .gray)
                                                                                                .lineLimit(1)
                                                                                        }
                                                                                        Spacer()
                                                                                    }
                                                                                    // ⚡️ FIX 4: Added explicit horizontal padding to push tracks away from the edge!
                                                                                    .padding(.horizontal, 20)
                                                                                    .contentShape(Rectangle())
                                                                                }
                                                                                .buttonStyle(.plain)
                                                                            }
                                                                        }
                                                                        .padding(.vertical, 12)
                                                                    }
                                                                }
                                                            }
                                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                                            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)),
                                                                                   removal: .opacity.combined(with: .move(edge: .leading))))
                                                        }
                        }
                        .padding(.bottom, 8)
                        .transition(.opacity)
                    }
                }
                .frame(width: isExpanded ? expandedWidth : collapsedWidth,
                       height: isExpanded ? expandedHeight : notchHeight)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isExpanded)
            .onHover { h in isExpanded = h }
            
            Spacer()
        }
        .frame(width: expandedWidth, height: 200)
        .edgesIgnoringSafeArea(.all)
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
