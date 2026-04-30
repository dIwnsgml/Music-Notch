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
    
    @State private var phase = false
    
    // ⚡️ Exaggerated heights so it bounces energetically when playing
    let maxHeights: [CGFloat] = [16, 24, 18, 22]
    
    // ⚡️ Desynced durations so it looks like organic, chaotic audio
    let durations: [Double] = [0.35, 0.42, 0.28, 0.38]
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(isPlaying ? color : Color.gray.opacity(0.5))
                // 1. If playing & phase is true, bounce up to Max. Otherwise, sit at 4.
                    .frame(width: 3, height: isPlaying ? (phase ? maxHeights[index] : 4) : 4)
                
                // 2. THE FIX: Dynamically swap the physics engine based on playback state!
                    .animation(
                        isPlaying
                        ? .easeInOut(duration: durations[index]).repeatForever(autoreverses: true)
                        : .easeOut(duration: 0.3), // ⚡️ Gracefully coasts to a stop when paused!
                        value: phase
                    )
                
                // 3. Smooth color fading
                    .animation(.easeOut(duration: 0.3), value: isPlaying)
            }
        }
        .onChange(of: isPlaying) { playing in
            if playing {
                // A tiny 0.05s delay gives SwiftUI enough time to register the new
                // .repeatForever modifier before we pull the trigger on the 'phase' state.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    phase = true
                }
            } else {
                // Instantly collapses the wave with the .easeOut animation
                phase = false
            }
        }
        .onAppear {
            if isPlaying {
                phase = true
            }
        }
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
