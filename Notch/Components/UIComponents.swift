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

    private let maxHeights: [CGFloat] = [16, 24, 18, 22]
    private let lowScales: [CGFloat] = [0.28, 0.22, 0.34, 0.26]
    private let highScales: [CGFloat] = [0.90, 1.00, 0.78, 0.92]
    private let durations: [Double] = [0.42, 0.36, 0.50, 0.40]
    private let delays: [Double] = [0.0, 0.08, 0.15, 0.04]

    @State private var animationPhase = false

    private var shouldAnimate: Bool {
        isPlaying && animates
    }
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(maxHeights.indices, id: \.self) { index in
                Capsule()
                    .fill(isPlaying ? color : Color.gray.opacity(0.5))
                    .frame(width: 3, height: maxHeights[index])
                    .scaleEffect(y: barScale(index: index), anchor: .center)
                    .animation(shouldAnimate ? barAnimation(index: index) : nil, value: animationPhase)
            }
        }
        .frame(height: maxHeights.max() ?? 24)
        .id(shouldAnimate ? "wave-playing" : "wave-paused")
        .transaction { transaction in
            if !shouldAnimate {
                transaction.disablesAnimations = true
                transaction.animation = nil
            }
        }
        .task(id: shouldAnimate) {
            animationPhase = false
            guard shouldAnimate else { return }
            await Task.yield()
            guard !Task.isCancelled else { return }
            animationPhase = true
        }
    }

    private func barScale(index: Int) -> CGFloat {
        guard isPlaying else { return 0.22 }
        guard animates else { return 0.55 }
        return animationPhase ? highScales[index] : lowScales[index]
    }

    private func barAnimation(index: Int) -> Animation {
        guard isPlaying, animates else {
            return .easeOut(duration: 0.18)
        }

        return .easeInOut(duration: durations[index])
            .repeatForever(autoreverses: true)
            .delay(delays[index])
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
