import os

with open("Notch/Views/WidgetFactoryView.swift", "r") as f:
    lines = f.readlines()

start_idx = -1
end_idx = -1

for i, line in enumerate(lines):
    if "private var tapeWindow: some View" in line or "private var staticTapeWindowBackground: some View" in line:
        start_idx = i
        break

for i, line in enumerate(lines):
    if "private struct CassetteArtworkView: View {" in line:
        end_idx = i
        break

if start_idx != -1 and end_idx != -1:
    new_content = lines[:start_idx]
    
    replacement = """    private var staticTapeWindowBackground: some View {
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
    new_content.append(replacement)
    new_content.extend(lines[end_idx:])
    
    with open("Notch/Views/WidgetFactoryView.swift", "w") as f:
        f.writelines(new_content)
    print("Patched!")
else:
    print(f"Could not find markers. start: {start_idx}, end: {end_idx}")
