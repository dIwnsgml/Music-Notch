import re

with open("Notch/Views/WidgetFactoryView.swift", "r") as f:
    content = f.read()

old_turntable_record_view = re.search(r'private struct TurntableRecordView: View \{.*?\n\nprivate struct TurntableTonearmView', content, re.DOTALL)
if not old_turntable_record_view:
    print("Could not find TurntableRecordView")
    exit(1)

old_str = old_turntable_record_view.group(0).replace("\nprivate struct TurntableTonearmView", "")

new_str = """private struct TurntableRecordView: View {
    let artworkURL: URL?
    let artworkIdentity: String
    let isPlaying: Bool
    let hasMedia: Bool
    let size: CGFloat
    let spinSpeed: Double

    @State private var displayedArtworkURL: URL? = nil
    @State private var labelFlipDegrees: Double = 0
    @State private var artworkTransitionTask: Task<Void, Never>? = nil

    var body: some View {
        ZStack {
            AnimatedTurntableDisc(
                size: size,
                isPlaying: isPlaying,
                spinSpeed: spinSpeed,
                hasMedia: hasMedia,
                displayedArtworkURL: displayedArtworkURL,
                labelFlipDegrees: labelFlipDegrees
            )

            TurntableReflection(size: size)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .onAppear {
            displayedArtworkURL = artworkURL
        }
        .onChange(of: artworkIdentity) { _, _ in
            rotateToArtwork(artworkURL)
        }
        .onDisappear {
            artworkTransitionTask?.cancel()
            artworkTransitionTask = nil
        }
    }

    private func rotateToArtwork(_ newArtworkURL: URL?) {
        artworkTransitionTask?.cancel()

        withAnimation(.easeIn(duration: 0.16)) {
            labelFlipDegrees = 88
        }

        artworkTransitionTask = Task {
            try? await Task.sleep(nanoseconds: 160_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                displayedArtworkURL = newArtworkURL
                labelFlipDegrees = -88

                withAnimation(.easeOut(duration: 0.22)) {
                    labelFlipDegrees = 0
                }

                artworkTransitionTask = nil
            }
        }
    }
}

private struct TurntableReflection: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color.white.opacity(0.16), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: size * 0.84, height: size * 0.08)
                .blur(radius: 4)
                .rotationEffect(.degrees(-8))
                .blendMode(.screen)

            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                .padding(5)
        }
    }
}

private struct AnimatedTurntableDisc: View {
    let size: CGFloat
    let isPlaying: Bool
    let spinSpeed: Double
    let hasMedia: Bool
    let displayedArtworkURL: URL?
    let labelFlipDegrees: Double

    @State private var rotation: Double = 0
    @State private var spinVelocity: Double = 0
    @State private var lastFrameDate: Date?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isPlaying && abs(spinVelocity) < 0.05)) { timeline in
            StaticTurntableDisc(
                size: size,
                hasMedia: hasMedia,
                displayedArtworkURL: displayedArtworkURL,
                labelFlipDegrees: labelFlipDegrees
            )
            .rotationEffect(.degrees(rotation))
            .onAppear {
                lastFrameDate = timeline.date
                spinVelocity = isPlaying ? targetSpinVelocity : 0
            }
            .onChange(of: timeline.date) { _, date in
                advanceSpin(to: date)
            }
            .onChange(of: isPlaying) { _, _ in
                lastFrameDate = timeline.date
            }
        }
    }

    private var targetSpinVelocity: Double {
        122 * min(max(spinSpeed, 0.5), 2.0)
    }

    private func advanceSpin(to date: Date) {
        guard let lastFrameDate else {
            self.lastFrameDate = date
            return
        }

        let delta = min(max(date.timeIntervalSince(lastFrameDate), 0), 0.06)
        self.lastFrameDate = date

        let target = isPlaying ? targetSpinVelocity : 0
        let response = isPlaying ? 4.8 : 2.4
        let blend = min(1, delta * response)
        spinVelocity += (target - spinVelocity) * blend

        if !isPlaying && abs(spinVelocity) < 0.05 {
            spinVelocity = 0
        }

        rotation = (rotation + spinVelocity * delta).truncatingRemainder(dividingBy: 360)
    }
}

private struct StaticTurntableDisc: View {
    let size: CGFloat
    let hasMedia: Bool
    let displayedArtworkURL: URL?
    let labelFlipDegrees: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.025, green: 0.025, blue: 0.025),
                            Color.black,
                            Color(red: 0.055, green: 0.055, blue: 0.052),
                            Color.black
                        ],
                        center: .center,
                        startRadius: 3,
                        endRadius: size * 0.55
                    )
                )

            Circle()
                .stroke(Color.black.opacity(0.85), lineWidth: 10)
                .padding(3)

            Circle()
                .stroke(Color.black.opacity(0.42), lineWidth: 4)
                .padding(13)

            Circle()
                .stroke(Color.white.opacity(0.055), lineWidth: 1.5)
                .padding(18)

            ForEach(0..<46, id: \\.self) { index in
                let ringSize = size * (0.25 + CGFloat(index) * 0.016)
                Circle()
                    .stroke(
                        Color.white.opacity(index.isMultiple(of: 6) ? 0.065 : 0.022),
                        lineWidth: index.isMultiple(of: 6) ? 0.75 : 0.38
                    )
                    .frame(width: ringSize, height: ringSize)
            }

            ForEach(0..<36, id: \\.self) { index in
                Rectangle()
                    .fill(Color.white.opacity(index.isMultiple(of: 3) ? 0.018 : 0.009))
                    .frame(width: 1, height: size * 0.36)
                    .offset(y: -size * 0.18)
                    .rotationEffect(.degrees(Double(index) * 10))
                    .blendMode(.screen)
            }

            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.11),
                            Color.clear,
                            Color.white.opacity(0.06),
                            Color.clear
                        ],
                        center: .center
                    ),
                    lineWidth: 8
                )
                .padding(size * 0.09)

            Circle()
                .fill(labelBackground)
                .frame(width: size * 0.50, height: size * 0.50)
                .overlay(labelArtwork)
                .rotation3DEffect(
                    .degrees(labelFlipDegrees),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.48
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.42), radius: 4, y: 2)

            Circle()
                .fill(Color.white.opacity(0.88))
                .frame(width: size * 0.058, height: size * 0.058)
                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
        }
    }

    private var labelBackground: some ShapeStyle {
        RadialGradient(
            colors: [
                Color.white.opacity(hasMedia ? 0.32 : 0.18),
                Color.gray.opacity(hasMedia ? 0.22 : 0.10),
                Color.black.opacity(0.18)
            ],
            center: .center,
            startRadius: 1,
            endRadius: size * 0.25
        )
    }

    @ViewBuilder
    private var labelArtwork: some View {
        if hasMedia, let displayedArtworkURL {
            AsyncImage(url: displayedArtworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                ProgressView()
                    .controlSize(.mini)
            }
            .clipShape(Circle())
        } else {
            Image(systemName: "music.note")
                .font(.system(size: size * 0.16, weight: .bold))
                .foregroundColor(.white.opacity(0.58))
        }
    }
}"""

content = content.replace(old_str, new_str)
with open("Notch/Views/WidgetFactoryView.swift", "w") as f:
    f.write(content)
print("Patched!")
