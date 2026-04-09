import SwiftUI

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
            ForEach(0..<4, id: \.self) { index in
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
