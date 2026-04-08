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

struct ContentView: View {
    @State private var isExpanded = false
    @StateObject private var nowPlaying = NowPlayingManager()
    
    @State private var isDragging = false
    @State private var dragProgress: Double = 0.0
    let localTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    let notchHeight: CGFloat = 32
    let collapsedWidth: CGFloat = 300
    let expandedWidth: CGFloat = 380

    var body: some View {
        let hasMedia = nowPlaying.currentSong != "No Music" && nowPlaying.currentSong != "NOT_PLAYING"
        let expandedHeight: CGFloat = !nowPlaying.lyrics.isEmpty ? 164 : 100

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
                            Color.clear.frame(height: notchHeight - 8)
                            
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
                                    Text(hasMedia ? nowPlaying.currentSong : "Nothing playing")
                                        .font(.system(size: 14, weight: .bold)).foregroundColor(.white).lineLimit(1)
                                }
                                .padding(.leading, 6)
                                
                                Spacer()
                                
                                if hasMedia {
                                    HStack(spacing: 12) {
                                        Button(action: { nowPlaying.skipBackward() }) { Image(systemName: "backward.fill").foregroundColor(.white) }.buttonStyle(.plain)
                                        Button(action: { nowPlaying.togglePlayPause() }) { Image(systemName: nowPlaying.isPlaying ? "pause.fill" : "play.fill").foregroundColor(.white) }.buttonStyle(.plain)
                                        Button(action: { nowPlaying.skipForward() }) { Image(systemName: "forward.fill").foregroundColor(.white) }.buttonStyle(.plain)
                                        Button(action: { nowPlaying.toggleLoop() }) {
                                            Image(systemName: nowPlaying.loopMode == 2 ? "repeat.1" : "repeat")
                                                .foregroundColor(nowPlaying.loopMode > 0 ? .green : .white.opacity(0.6))
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
                                            Capsule().fill(Color.white.opacity(0.2)).frame(height: 6)
                                            Capsule().fill(Color.white).frame(width: max(0, geo.size.width * CGFloat(isDragging ? dragProgress : (nowPlaying.currentTime / nowPlaying.duration))), height: 6)
                                        }
                                        .gesture(DragGesture(minimumDistance: 0)
                                            .onChanged { v in isDragging = true; dragProgress = min(max(0, v.location.x / geo.size.width), 1) }
                                            .onEnded { v in nowPlaying.seek(to: min(max(0, v.location.x / geo.size.width), 1)); DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isDragging = false } }
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
                                                // ⚡️ JITTER FIX: Constant font weight stops the layout engine from popping
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
