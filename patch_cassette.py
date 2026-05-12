import re

with open("Notch/Views/WidgetFactoryView.swift", "r") as f:
    content = f.read()

# We need to find `private var staticTapeWindowBackground` and `private var cassetteBottom` to find where the split is.
# Wait, let's just replace the whole CassetteTapeDeckView and all its related properties.

pattern = r'private struct CassetteTapeDeckView: View \{.*?\nprivate struct CassetteBottomWindow: Shape \{'
match = re.search(pattern, content, re.DOTALL)

if not match:
    print("Could not find CassetteTapeDeckView block.")
    exit(1)

old_str = match.group(0).replace("\nprivate struct CassetteBottomWindow: Shape {", "")

new_str = """private struct CassetteTapeDeckView: View {
    let artworkURL: URL?
    let artworkIdentity: String
    let title: String
    let artist: String
    let isPlaying: Bool
    let hasMedia: Bool
    let playbackProgress: CGFloat
    let width: CGFloat
    let height: CGFloat
    let reelSpeed: Double
    let showTrackInfo: Bool
    let showTrackTitle: Bool
    let showTrackArtist: Bool
    let showAlbumCover: Bool
    let accentColor: Color
    let labelColor: String
    let bodyColor: String

    @State private var artworkPulse = false

    var body: some View {
        ZStack {
            cassetteShell
            cassetteLabel
            staticTapeWindowBackground
            AnimatedCassetteReels(
                width: width,
                height: height,
                playbackProgress: playbackProgress,
                isPlaying: isPlaying,
                reelSpeed: reelSpeed
            )
            cassetteBottom
            screws
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.34), radius: 13, x: 0, y: 8)
        .onChange(of: artworkIdentity) { _, _ in
            triggerArtworkPulse()
        }
    }

    private var baseBodyColor: Color {
        switch bodyColor {
        case "white": return Color(white: 0.85)
        case "transparent": return Color.black.opacity(0.3)
        case "silver": return Color(white: 0.70)
        case "retroblue": return Color(red: 0.20, green: 0.40, blue: 0.75)
        case "retropink": return Color(red: 0.85, green: 0.35, blue: 0.65)
        case "retroyellow": return Color(red: 0.90, green: 0.75, blue: 0.20)
        case "dynamic": return accentColor
        case "black": fallthrough
        default: return Color(red: 0.11, green: 0.11, blue: 0.10)
        }
    }

    private var cassetteShell: some View {
        let currentBodyColor = baseBodyColor

        return RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        currentBodyColor,
                        currentBodyColor.opacity(0.85),
                        currentBodyColor.opacity(0.7)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .animation(.easeInOut(duration: 0.5), value: currentBodyColor)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1.1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(0.60), lineWidth: 3)
                    .padding(7)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.055), lineWidth: 1)
                    .padding(10)
            )
            .overlay(shellTexture)
    }

    private var shellTexture: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.025),
                        Color.clear,
                        Color.black.opacity(0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .blendMode(.overlay)
    }

    private var baseLabelColor: Color {
        switch labelColor {
        case "red": return Color(red: 0.85, green: 0.25, blue: 0.25)
        case "blue": return Color(red: 0.25, green: 0.45, blue: 0.85)
        case "green": return Color(red: 0.25, green: 0.75, blue: 0.35)
        case "purple": return Color(red: 0.55, green: 0.25, blue: 0.75)
        case "gray": return Color(white: 0.65)
        case "pink": return Color(red: 0.95, green: 0.55, blue: 0.65)
        case "cyan": return Color(red: 0.15, green: 0.85, blue: 0.85)
        case "yellow": return Color(red: 0.95, green: 0.80, blue: 0.20)
        case "dynamic": return accentColor
        case "orange": fallthrough
        default: return Color(red: 1.0, green: 0.58, blue: 0.05)
        }
    }

    private var cassetteLabel: some View {
        let labelWidth = width * 0.82
        let labelX = width / 2
        let topPanelHeight = height * 0.25
        let topPanelY = height * 0.27
        let orangeHeight = height * 0.34
        let orangeY = height * 0.52
        let coverSize = min(height * 0.17, 34)
        let titleLeft = showAlbumCover ? width * 0.24 : width * 0.14
        let titleWidth = width * 0.56

        let currentLabelColor = baseLabelColor

        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(red: 0.05, green: 0.05, blue: 0.045).opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .frame(width: labelWidth, height: height * 0.50)
                .position(x: labelX, y: height * 0.42)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            currentLabelColor.opacity(0.85),
                            currentLabelColor,
                            currentLabelColor.opacity(0.9)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .animation(.easeInOut(duration: 0.5), value: currentLabelColor)
                .frame(width: labelWidth, height: orangeHeight)
                .position(x: labelX, y: orangeY)

            Rectangle()
                .fill(Color.black.opacity(0.90))
                .frame(width: labelWidth, height: topPanelHeight)
                .position(x: labelX, y: topPanelY)

            Text(showTrackInfo && showTrackArtist && !artist.isEmpty ? artist.lowercased() : "wave notch")
                .font(.system(size: max(13, height * 0.155), weight: .heavy, design: .rounded))
                .foregroundColor(currentLabelColor)
                .animation(.easeInOut(duration: 0.5), value: currentLabelColor)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .frame(width: width * 0.42, alignment: .leading)
                .position(x: width * 0.30, y: height * 0.30)

            VStack(alignment: .trailing, spacing: -4) {
                Text("90")
                    .font(.system(size: max(34, height * 0.35), weight: .black, design: .rounded))
                    .foregroundColor(currentLabelColor)
                    .animation(.easeInOut(duration: 0.5), value: currentLabelColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.64)
                Text("2 x 45 min.")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundColor(currentLabelColor.opacity(0.85))
                    .animation(.easeInOut(duration: 0.5), value: currentLabelColor)
            }
            .frame(width: width * 0.19, alignment: .trailing)
            .position(x: width * 0.76, y: height * 0.27)

            if showAlbumCover {
                CassetteArtworkView(artworkURL: artworkURL, hasMedia: hasMedia)
                    .frame(width: coverSize, height: coverSize)
                    .scaleEffect(artworkPulse ? 1.06 : 1)
                    .rotationEffect(.degrees(-3))
                    .position(x: width * 0.17, y: height * 0.68)
                    .animation(.spring(response: 0.34, dampingFraction: 0.72), value: artworkPulse)
            } else {
                Text("1")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.black.opacity(0.80))
                    .position(x: width * 0.16, y: height * 0.70)
            }

            if showTrackInfo {
                VStack(alignment: .leading, spacing: 0) {
                    if showTrackTitle {
                        MarqueeText(
                            text: title.uppercased(),
                            font: .system(size: max(14, height * 0.15), weight: .heavy, design: .rounded),
                            alignment: .leading
                        )
                        .frame(height: height * 0.17)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.8), radius: 1, x: 0, y: 1)
                        .id("cassette_title_\\(title)")
                    }
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.5), value: title)
                .frame(width: titleWidth, alignment: .leading)
                .position(x: titleLeft + titleWidth / 2, y: height * 0.70)
            }

            Text("Compact\\nCassette")
                .font(.system(size: 7, weight: .bold, design: .rounded))
                .italic()
                .foregroundColor(.black.opacity(0.72))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(Color.black.opacity(0.70), lineWidth: 1)
                )
                .rotationEffect(.degrees(-5))
                .position(x: width * 0.80, y: height * 0.61)

            Rectangle()
                .fill(Color.black.opacity(0.70))
                .frame(width: labelWidth * 0.80, height: 1.2)
                .position(x: width * 0.48, y: height * 0.80)
        }
    }

    private var staticTapeWindowBackground: some View {
        let windowWidth = width * 0.58
        let windowHeight = height * 0.21
        let windowY = height * 0.50

        return ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.black.opacity(0.94))
                .frame(width: windowWidth, height: windowHeight)
                .position(x: width / 2, y: windowY)
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        .frame(width: windowWidth, height: windowHeight)
                        .position(x: width / 2, y: windowY)
                )
                .shadow(color: .black.opacity(0.52), radius: 4, x: 0, y: 2)

            Capsule()
                .fill(Color.white.opacity(0.22))
                .frame(width: width * 0.24, height: 1.2)
                .position(x: width / 2, y: windowY)

            HStack(spacing: width * 0.035) {
                ForEach(["100", "50", "0"], id: \\.self) { marker in
                    Text(marker)
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.28))
                }
            }
            .position(x: width / 2, y: windowY + windowHeight * 0.34)
        }
    }

    private var cassetteBottom: some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: width * 0.18, y: height * 0.74))
                path.addLine(to: CGPoint(x: width * 0.82, y: height * 0.74))
                path.addLine(to: CGPoint(x: width * 0.88, y: height * 0.92))
                path.addLine(to: CGPoint(x: width * 0.12, y: height * 0.92))
                path.closeSubpath()
            }
            .fill(Color.black.opacity(0.64))
            .overlay(
                Path { path in
                    path.move(to: CGPoint(x: width * 0.18, y: height * 0.74))
                    path.addLine(to: CGPoint(x: width * 0.82, y: height * 0.74))
                    path.addLine(to: CGPoint(x: width * 0.88, y: height * 0.92))
                    path.addLine(to: CGPoint(x: width * 0.12, y: height * 0.92))
                    path.closeSubpath()
                }
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
            )

            ForEach(0..<3, id: \\.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.black.opacity(0.50))
                    .frame(width: width * 0.12, height: height * 0.20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                    .position(x: width * (0.25 + CGFloat(index) * 0.25), y: height * 0.84)
            }

            ForEach(0..<4, id: \\.self) { index in
                Circle()
                    .fill(Color.white.opacity(0.42))
                    .frame(width: height * 0.105, height: height * 0.105)
                    .overlay(Circle().stroke(Color.black.opacity(0.42), lineWidth: 1))
                    .shadow(color: .black.opacity(0.32), radius: 2, y: 1)
                    .position(x: width * (0.32 + CGFloat(index) * 0.12), y: height * 0.86)
            }
        }
    }

    private var screws: some View {
        ZStack {
            ForEach(Array(screwPoints.enumerated()), id: \\.offset) { _, point in
                CassetteScrewView()
                    .frame(width: height * 0.12, height: height * 0.12)
                    .position(x: point.x * width, y: point.y * height)
            }
        }
    }

    private var screwPoints: [CGPoint] {
        [
            CGPoint(x: 0.06, y: 0.10),
            CGPoint(x: 0.94, y: 0.10),
            CGPoint(x: 0.06, y: 0.91),
            CGPoint(x: 0.94, y: 0.91)
        ]
    }

    private func triggerArtworkPulse() {
        artworkPulse = true
        Task {
            try? await Task.sleep(nanoseconds: 260_000_000)
            await MainActor.run {
                artworkPulse = false
            }
        }
    }
}

private struct AnimatedCassetteReels: View {
    let width: CGFloat
    let height: CGFloat
    let playbackProgress: CGFloat
    let isPlaying: Bool
    let reelSpeed: Double

    @State private var reelRotation: Double = 0
    @State private var reelVelocity: Double = 0
    @State private var tapePhase: Double = 0
    @State private var lastFrameDate: Date?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isPlaying && abs(reelVelocity) < 0.05)) { timeline in
            let windowHeight = height * 0.21
            let windowY = height * 0.50
            let leftCenter = CGPoint(x: width * 0.35, y: windowY)
            let rightCenter = CGPoint(x: width * 0.65, y: windowY)
            let reelSize = height * 0.29
            let clampedProgress = min(max(playbackProgress, 0), 1)
            let leftSpool = 0.76 - clampedProgress * 0.34
            let rightSpool = 0.38 + clampedProgress * 0.34

            ZStack {
                CassetteTapeStripView(phase: tapePhase, isPlaying: isPlaying)
                    .frame(width: width * 0.22, height: windowHeight * 0.52)
                    .position(x: width / 2, y: windowY)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                CassetteReelView(rotation: reelRotation, spoolFraction: leftSpool, isPlaying: isPlaying)
                    .frame(width: reelSize, height: reelSize)
                    .position(leftCenter)

                CassetteReelView(rotation: -reelRotation * 1.08, spoolFraction: rightSpool, isPlaying: isPlaying)
                    .frame(width: reelSize, height: reelSize)
                    .position(rightCenter)
            }
            .onAppear {
                lastFrameDate = timeline.date
                reelVelocity = isPlaying ? targetReelVelocity : 0
            }
            .onChange(of: timeline.date) { _, date in
                advanceMotion(to: date)
            }
            .onChange(of: isPlaying) { _, _ in
                lastFrameDate = timeline.date
            }
        }
    }

    private var targetReelVelocity: Double {
        235 * min(max(reelSpeed, 0.5), 2.0)
    }

    private func advanceMotion(to date: Date) {
        guard let lastFrameDate else {
            self.lastFrameDate = date
            return
        }

        let delta = min(max(date.timeIntervalSince(lastFrameDate), 0), 0.06)
        self.lastFrameDate = date

        let target = isPlaying ? targetReelVelocity : 0
        let response = isPlaying ? 5.2 : 2.6
        let blend = min(1, delta * response)
        reelVelocity += (target - reelVelocity) * blend

        if !isPlaying && abs(reelVelocity) < 0.05 {
            reelVelocity = 0
        }

        reelRotation = (reelRotation + reelVelocity * delta).truncatingRemainder(dividingBy: 360)
        tapePhase = (tapePhase + reelVelocity * delta * 0.045).truncatingRemainder(dividingBy: 16)
    }
}
"""

content = content.replace(old_str, new_str)

with open("Notch/Views/WidgetFactoryView.swift", "w") as f:
    f.write(content)
print("Cassette Patched!")
