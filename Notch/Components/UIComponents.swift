import SwiftUI
import Combine

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
    var animates: Bool = true

    // ⚡️ Exaggerated heights so it bounces energetically when playing
    private let maxHeights: [CGFloat] = [16, 24, 18, 22]
    private let waveformFrameInterval: TimeInterval = 1.0 / 8.0
    
    var body: some View {
        TimelineView(.animation(minimumInterval: waveformFrameInterval, paused: !isPlaying || !animates)) { timeline in
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(isPlaying ? color : Color.gray.opacity(0.5))
                        .frame(width: 3, height: barHeight(index: index, date: timeline.date))
                        .animation(.easeOut(duration: 0.22), value: isPlaying)
                }
            }
        }
    }

    private func barHeight(index: Int, date: Date) -> CGFloat {
        guard isPlaying else { return 4 }
        guard animates else { return maxHeights[index] * 0.55 }

        let speed = [5.4, 6.2, 7.1, 5.8][index]
        let offset = Double(index) * 1.37
        let wave = (sin(date.timeIntervalSinceReferenceDate * speed + offset) + 1) * 0.5
        return 4 + (maxHeights[index] - 4) * CGFloat(0.28 + wave * 0.72)
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
            let containerHeight: CGFloat? = proxy.size.height > 0 ? proxy.size.height : nil
            
            if textWidth > containerWidth && containerWidth > 0 {
                HStack(spacing: spacing) {
                    Text(text).font(font).lineLimit(1).fixedSize()
                    Text(text).font(font).lineLimit(1).fixedSize()
                }
                .frame(height: containerHeight, alignment: .center)
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
                    .frame(width: containerWidth, height: containerHeight, alignment: alignment)
            }
        }
        .clipped()
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

// ⚡️ NATIVE MACOS GLASS EFFECT
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var alpha: CGFloat = 1.0

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.appearance = NSAppearance(named: .vibrantDark)
        view.alphaValue = alpha
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.alphaValue = alpha
    }
}
