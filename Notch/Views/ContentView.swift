import SwiftUI
import Combine
import KeyboardShortcuts
import UniformTypeIdentifiers

private enum FileDropTypeIdentifiers {
    static let all = [
        UTType.fileURL.identifier,
        UTType.url.identifier,
        UTType.item.identifier,
        UTType.data.identifier,
        UTType.utf8PlainText.identifier,
        UTType.plainText.identifier,
        NSPasteboard.PasteboardType("NSFilenamesPboardType").rawValue
    ]
}

enum ThemePresetCategory: String, CaseIterable, Identifiable {
    case dynamic = "Dynamic Wallpapers"
    case landscape = "Landscape"
    case cityscape = "Cityscape"
    case minimal = "Minimal"

    var id: String { rawValue }
}

enum ThemePresetStyle: String {
    case venturaGlow
    case tahoeBlue
    case sequoiaPrism
    case sonomaRibbon
    case macintoshMono
    case tahoeDay
    case sequoiaSunrise
    case sonomaHorizon
    case coastalDrift
    case dubaiHaze
    case glassTowers
    case nightCrossing
    case graphiteGlass
    case cherryBlossom
    case cobaltBloom
}

struct ThemePreset: Identifiable, Equatable {
    let id: String
    let name: String
    let subtitle: String
    let category: ThemePresetCategory
    let style: ThemePresetStyle

    static let defaultID = ThemePresetStyle.venturaGlow.rawValue

    static let all: [ThemePreset] = [
        ThemePreset(id: ThemePresetStyle.venturaGlow.rawValue, name: "Ventura", subtitle: "Muted warm abstract", category: .dynamic, style: .venturaGlow),
        ThemePreset(id: ThemePresetStyle.tahoeBlue.rawValue, name: "Tahoe", subtitle: "Blue dynamic waves", category: .dynamic, style: .tahoeBlue),
        ThemePreset(id: ThemePresetStyle.sequoiaPrism.rawValue, name: "Sequoia", subtitle: "Sharp color prisms", category: .dynamic, style: .sequoiaPrism),
        ThemePreset(id: ThemePresetStyle.sonomaRibbon.rawValue, name: "Sonoma", subtitle: "Rolling color ribbon", category: .dynamic, style: .sonomaRibbon),
        ThemePreset(id: ThemePresetStyle.macintoshMono.rawValue, name: "Macintosh", subtitle: "Classic mono pattern", category: .dynamic, style: .macintoshMono),
        ThemePreset(id: ThemePresetStyle.tahoeDay.rawValue, name: "Tahoe Day", subtitle: "Lake and mountain light", category: .landscape, style: .tahoeDay),
        ThemePreset(id: ThemePresetStyle.sequoiaSunrise.rawValue, name: "Sequoia Sunrise", subtitle: "Forest morning glow", category: .landscape, style: .sequoiaSunrise),
        ThemePreset(id: ThemePresetStyle.sonomaHorizon.rawValue, name: "Sonoma Horizon", subtitle: "Soft hills at sunset", category: .landscape, style: .sonomaHorizon),
        ThemePreset(id: ThemePresetStyle.coastalDrift.rawValue, name: "Coastal Drift", subtitle: "Beach and water split", category: .landscape, style: .coastalDrift),
        ThemePreset(id: ThemePresetStyle.dubaiHaze.rawValue, name: "Dubai Haze", subtitle: "Golden skyline wash", category: .cityscape, style: .dubaiHaze),
        ThemePreset(id: ThemePresetStyle.glassTowers.rawValue, name: "Glass Towers", subtitle: "Cool architectural glass", category: .cityscape, style: .glassTowers),
        ThemePreset(id: ThemePresetStyle.nightCrossing.rawValue, name: "Night Crossing", subtitle: "Neon city lights", category: .cityscape, style: .nightCrossing),
        ThemePreset(id: ThemePresetStyle.graphiteGlass.rawValue, name: "Graphite", subtitle: "Quiet dark glass", category: .minimal, style: .graphiteGlass),
        ThemePreset(id: ThemePresetStyle.cherryBlossom.rawValue, name: "Cherry Blossom", subtitle: "Soft pink canopy", category: .minimal, style: .cherryBlossom),
        ThemePreset(id: ThemePresetStyle.cobaltBloom.rawValue, name: "Cobalt Bloom", subtitle: "Deep blue glow", category: .minimal, style: .cobaltBloom)
    ]

    static func preset(id: String) -> ThemePreset {
        all.first { $0.id == id } ?? all[0]
    }

    static func presets(in category: ThemePresetCategory) -> [ThemePreset] {
        all.filter { $0.category == category }
    }
}

struct ThemePresetBackground: View {
    let presetID: String

    private var style: ThemePresetStyle {
        ThemePreset.preset(id: presetID).style
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                baseLayer(for: style)
                detailLayer(for: style, size: size)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .drawingGroup(opaque: false, colorMode: .linear)
        }
    }

    @ViewBuilder
    private func baseLayer(for style: ThemePresetStyle) -> some View {
        switch style {
        case .venturaGlow:
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.16, blue: 0.38),
                    Color(red: 0.33, green: 0.34, blue: 0.58),
                    Color(red: 0.82, green: 0.42, blue: 0.18),
                    Color(red: 0.70, green: 0.18, blue: 0.16),
                    Color(red: 0.14, green: 0.04, blue: 0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .tahoeBlue:
            LinearGradient(
                colors: [
                    Color(red: 0.64, green: 0.91, blue: 1.00),
                    Color(red: 0.09, green: 0.37, blue: 0.92),
                    Color(red: 0.02, green: 0.10, blue: 0.44)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sequoiaPrism:
            LinearGradient(
                colors: [
                    Color(red: 1.00, green: 0.43, blue: 0.58),
                    Color(red: 0.99, green: 0.66, blue: 0.14),
                    Color(red: 0.42, green: 0.24, blue: 0.92),
                    Color(red: 0.12, green: 0.75, blue: 0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .sonomaRibbon:
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.34, blue: 0.24),
                    Color(red: 0.10, green: 0.56, blue: 0.95),
                    Color(red: 0.36, green: 0.82, blue: 0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .macintoshMono:
            LinearGradient(
                colors: [
                    Color(red: 0.82, green: 0.82, blue: 0.82),
                    Color(red: 0.54, green: 0.54, blue: 0.56),
                    Color(red: 0.16, green: 0.16, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .tahoeDay:
            LinearGradient(
                colors: [
                    Color(red: 0.54, green: 0.82, blue: 1.00),
                    Color(red: 0.12, green: 0.48, blue: 0.90),
                    Color(red: 0.03, green: 0.33, blue: 0.58)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .sequoiaSunrise:
            LinearGradient(
                colors: [
                    Color(red: 1.00, green: 0.68, blue: 0.28),
                    Color(red: 0.50, green: 0.26, blue: 0.12),
                    Color(red: 0.08, green: 0.18, blue: 0.09)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .sonomaHorizon:
            LinearGradient(
                colors: [
                    Color(red: 1.00, green: 0.73, blue: 0.38),
                    Color(red: 0.51, green: 0.67, blue: 0.25),
                    Color(red: 0.17, green: 0.34, blue: 0.17)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .coastalDrift:
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.47, blue: 0.68),
                    Color(red: 0.15, green: 0.75, blue: 0.80),
                    Color(red: 0.95, green: 0.77, blue: 0.42)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .dubaiHaze:
            LinearGradient(
                colors: [
                    Color(red: 0.96, green: 0.76, blue: 0.55),
                    Color(red: 0.64, green: 0.38, blue: 0.67),
                    Color(red: 0.11, green: 0.11, blue: 0.20)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .glassTowers:
            LinearGradient(
                colors: [
                    Color(red: 0.78, green: 0.90, blue: 0.96),
                    Color(red: 0.35, green: 0.58, blue: 0.72),
                    Color(red: 0.09, green: 0.17, blue: 0.24)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .nightCrossing:
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.02, blue: 0.08),
                    Color(red: 0.10, green: 0.04, blue: 0.22),
                    Color(red: 0.80, green: 0.05, blue: 0.58)
                ],
                startPoint: .top,
                endPoint: .bottomTrailing
            )
        case .graphiteGlass:
            LinearGradient(
                colors: [
                    Color(red: 0.16, green: 0.17, blue: 0.18),
                    Color(red: 0.04, green: 0.05, blue: 0.06),
                    Color(red: 0.28, green: 0.25, blue: 0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .cherryBlossom:
            LinearGradient(
                colors: [
                    Color(red: 1.00, green: 0.79, blue: 0.89),
                    Color(red: 0.92, green: 0.30, blue: 0.55),
                    Color(red: 0.23, green: 0.32, blue: 0.46)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .cobaltBloom:
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.10, blue: 0.36),
                    Color(red: 0.08, green: 0.34, blue: 0.80),
                    Color(red: 0.76, green: 0.18, blue: 0.56)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private func detailLayer(for style: ThemePresetStyle, size: CGSize) -> some View {
        switch style {
        case .venturaGlow:
            softEllipse(color: Color(red: 1.00, green: 0.72, blue: 0.28).opacity(0.18), width: 0.66, height: 0.56, x: 0.16, y: -0.02, rotation: 18)
            softEllipse(color: Color(red: 0.95, green: 0.28, blue: 0.24).opacity(0.20), width: 0.70, height: 0.62, x: 0.24, y: 0.26, rotation: -14)
            softEllipse(color: Color(red: 0.14, green: 0.52, blue: 0.86).opacity(0.28), width: 0.72, height: 0.72, x: -0.30, y: -0.20, rotation: -18)
            softEllipse(color: Color(red: 0.46, green: 0.18, blue: 0.66).opacity(0.18), width: 0.64, height: 0.62, x: -0.18, y: 0.26, rotation: 26)
        case .tahoeBlue:
            diagonalRibbon(size: size, color: .white.opacity(0.20), y: 0.36, height: 0.16, slope: -0.20)
            diagonalRibbon(size: size, color: .cyan.opacity(0.28), y: 0.50, height: 0.22, slope: -0.12)
        case .sequoiaPrism:
            prism(size: size, color: .white.opacity(0.22), points: [CGPoint(x: 0.08, y: 1.0), CGPoint(x: 0.42, y: 0.0), CGPoint(x: 0.70, y: 1.0)])
            prism(size: size, color: .purple.opacity(0.28), points: [CGPoint(x: 0.45, y: 0.0), CGPoint(x: 1.0, y: 0.18), CGPoint(x: 0.68, y: 1.0)])
            prism(size: size, color: .yellow.opacity(0.20), points: [CGPoint(x: 0.0, y: 0.18), CGPoint(x: 0.37, y: 0.0), CGPoint(x: 0.18, y: 0.75)])
        case .sonomaRibbon:
            diagonalRibbon(size: size, color: .green.opacity(0.35), y: 0.55, height: 0.26, slope: 0.18)
            diagonalRibbon(size: size, color: .red.opacity(0.34), y: 0.26, height: 0.22, slope: -0.18)
            ellipse(color: .blue.opacity(0.25), width: 0.65, height: 0.55, x: 0.28, y: -0.15, rotation: 12)
        case .macintoshMono:
            symbolPattern(size: size)
        case .tahoeDay:
            mountain(size: size, color: Color.white.opacity(0.70), peakX: 0.34, peakY: 0.20, baseY: 0.62)
            mountain(size: size, color: Color(red: 0.08, green: 0.22, blue: 0.34).opacity(0.62), peakX: 0.74, peakY: 0.30, baseY: 0.66)
            lake(size: size, color: Color.cyan.opacity(0.35), y: 0.60)
        case .sequoiaSunrise:
            forest(size: size)
            ellipse(color: .orange.opacity(0.34), width: 0.55, height: 0.55, x: 0.20, y: -0.22, rotation: 0)
        case .sonomaHorizon:
            rollingHills(size: size)
        case .coastalDrift:
            diagonalRibbon(size: size, color: .white.opacity(0.72), y: 0.58, height: 0.10, slope: -0.28)
            diagonalRibbon(size: size, color: .green.opacity(0.26), y: 0.12, height: 0.36, slope: -0.20)
        case .dubaiHaze:
            skyline(size: size, warm: true)
        case .glassTowers:
            glassTowers(size: size)
        case .nightCrossing:
            skyline(size: size, warm: false)
            diagonalRibbon(size: size, color: .cyan.opacity(0.28), y: 0.64, height: 0.08, slope: 0.10)
        case .graphiteGlass:
            ellipse(color: .white.opacity(0.08), width: 0.70, height: 0.42, x: -0.18, y: -0.18, rotation: -15)
            ellipse(color: .orange.opacity(0.12), width: 0.58, height: 0.60, x: 0.30, y: 0.18, rotation: 20)
        case .cherryBlossom:
            blossomPattern(size: size)
        case .cobaltBloom:
            ellipse(color: .cyan.opacity(0.35), width: 0.68, height: 0.62, x: -0.20, y: -0.10, rotation: -18)
            ellipse(color: .pink.opacity(0.32), width: 0.72, height: 0.70, x: 0.25, y: 0.20, rotation: 15)
        }
    }

    private func ellipse(color: Color, width: CGFloat, height: CGFloat, x: CGFloat, y: CGFloat, rotation: Double) -> some View {
        Ellipse()
            .fill(color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(x: width, y: height)
            .offset(x: x * 240, y: y * 160)
            .rotationEffect(.degrees(rotation))
            .blur(radius: 18)
            .blendMode(.plusLighter)
    }

    private func softEllipse(color: Color, width: CGFloat, height: CGFloat, x: CGFloat, y: CGFloat, rotation: Double) -> some View {
        Ellipse()
            .fill(color)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(x: width, y: height)
            .offset(x: x * 240, y: y * 160)
            .rotationEffect(.degrees(rotation))
            .blur(radius: 22)
    }

    private func diagonalRibbon(size: CGSize, color: Color, y: CGFloat, height: CGFloat, slope: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: size.height * y))
            path.addLine(to: CGPoint(x: size.width, y: size.height * (y + slope)))
            path.addLine(to: CGPoint(x: size.width, y: size.height * (y + slope + height)))
            path.addLine(to: CGPoint(x: 0, y: size.height * (y + height)))
            path.closeSubpath()
        }
        .fill(color)
        .blur(radius: 4)
    }

    private func prism(size: CGSize, color: Color, points: [CGPoint]) -> some View {
        Path { path in
            guard let first = points.first else { return }
            path.move(to: CGPoint(x: first.x * size.width, y: first.y * size.height))
            for point in points.dropFirst() {
                path.addLine(to: CGPoint(x: point.x * size.width, y: point.y * size.height))
            }
            path.closeSubpath()
        }
        .fill(color)
    }

    private func mountain(size: CGSize, color: Color, peakX: CGFloat, peakY: CGFloat, baseY: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: size.height * baseY))
            path.addLine(to: CGPoint(x: size.width * peakX, y: size.height * peakY))
            path.addLine(to: CGPoint(x: size.width, y: size.height * baseY))
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()
        }
        .fill(color)
    }

    private func lake(size: CGSize, color: Color, y: CGFloat) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: size.height * y))
            path.addCurve(
                to: CGPoint(x: size.width, y: size.height * (y + 0.03)),
                control1: CGPoint(x: size.width * 0.26, y: size.height * (y - 0.06)),
                control2: CGPoint(x: size.width * 0.68, y: size.height * (y + 0.10))
            )
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()
        }
        .fill(color)
    }

    private func forest(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<13, id: \.self) { index in
                let x = CGFloat(index) / 12.0
                Rectangle()
                    .fill(Color(red: 0.09, green: 0.14, blue: 0.08).opacity(index.isMultiple(of: 2) ? 0.70 : 0.45))
                    .frame(width: max(2, size.width * 0.025), height: size.height * (0.42 + CGFloat(index % 4) * 0.08))
                    .offset(x: (x - 0.5) * size.width, y: size.height * 0.18)
            }
        }
    }

    private func rollingHills(size: CGSize) -> some View {
        ZStack {
            lake(size: size, color: Color(red: 0.42, green: 0.57, blue: 0.22).opacity(0.58), y: 0.45)
            lake(size: size, color: Color(red: 0.17, green: 0.35, blue: 0.14).opacity(0.74), y: 0.63)
        }
    }

    private func skyline(size: CGSize, warm: Bool) -> some View {
        ZStack(alignment: .bottom) {
            ForEach(0..<12, id: \.self) { index in
                let height = size.height * (0.20 + CGFloat((index * 7) % 8) * 0.035)
                Rectangle()
                    .fill((warm ? Color(red: 0.18, green: 0.12, blue: 0.20) : Color.black).opacity(0.55))
                    .frame(width: size.width * 0.08, height: height)
                    .offset(x: (CGFloat(index) / 11.0 - 0.5) * size.width, y: size.height * 0.36 - height / 2)
            }
            Path { path in
                path.move(to: CGPoint(x: size.width * 0.58, y: size.height * 0.85))
                path.addLine(to: CGPoint(x: size.width * 0.62, y: size.height * 0.18))
                path.addLine(to: CGPoint(x: size.width * 0.67, y: size.height * 0.85))
                path.closeSubpath()
            }
            .fill((warm ? Color.orange : Color.cyan).opacity(0.24))
        }
    }

    private func glassTowers(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.16))
                    .frame(width: size.width * 0.18, height: size.height * (0.55 + CGFloat(index % 2) * 0.18))
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -8 : 9))
                    .offset(x: (CGFloat(index) - 2) * size.width * 0.17, y: size.height * 0.08)
            }
        }
    }

    private func symbolPattern(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<18, id: \.self) { index in
                Image(systemName: ["command", "sparkles", "cursorarrow", "folder", "paintbrush"][index % 5])
                    .font(.system(size: max(8, size.width * 0.08), weight: .bold))
                    .foregroundColor(.black.opacity(0.18))
                    .rotationEffect(.degrees(Double((index * 23) % 360)))
                    .offset(
                        x: (CGFloat(index % 6) / 5.0 - 0.5) * size.width * 0.95,
                        y: (CGFloat(index / 6) / 2.0 - 0.5) * size.height * 0.86
                    )
            }
        }
    }

    private func blossomPattern(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<22, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 2) ? Color.white.opacity(0.22) : Color.pink.opacity(0.28))
                    .frame(width: size.width * 0.07, height: size.width * 0.07)
                    .offset(
                        x: (CGFloat((index * 37) % 100) / 100.0 - 0.5) * size.width,
                        y: (CGFloat((index * 61) % 100) / 100.0 - 0.5) * size.height
                    )
            }
        }
    }
}

enum AppTab {
    case player
    case playlist
}

struct ContentView: View {
    @State private var isExpanded = false
    @ObservedObject private var nowPlaying = NowPlayingManager.shared
    @State private var currentTab: AppTab = .player
    @StateObject private var dashboardManager = DashboardManager.shared
    @ObservedObject private var pomodoroTimer = PomodoroTimerManager.shared

    // ⚡️ USER SETTINGS
    @AppStorage("collapsedWidth") var storedCollapsedWidth: Double = 300.0
    @AppStorage("showSettingsButton") var showSettingsButton = true
    @AppStorage("enableHoverToExpand") var enableHoverToExpand = true
    @AppStorage("hoverDelay") var hoverDelay: Double = 0.0

    @AppStorage("showBannerOnControl") var showBannerOnControl = true
    @AppStorage("showSongChangeBanner") var showSongChangeBanner = true
    @AppStorage("bannerDuration") var bannerDuration: Double = 3.5
    @AppStorage("showLyrics") var showLyrics = true
    @AppStorage("showBannerLyrics") var showBannerLyrics = true
    @AppStorage("showGlowEffect") var showGlowEffect = true
    @AppStorage("visibleLyricLines") var visibleLyricLines = 3
    @AppStorage("invertSwipeDirection") var invertSwipeDirection = true
    @State private var isAppHidden = false

    // ⚡️ THEME
    @AppStorage("themeBackgroundType") var themeBackgroundType: String = "preset"
    @AppStorage("themePresetID") var themePresetID: String = ThemePreset.defaultID
    @AppStorage("themeBackgroundColorHex") var themeBackgroundColorHex: String = "000000"
    @AppStorage("themeBackgroundImagePath") var themeBackgroundImagePath: String = ""
    @AppStorage("themeBackgroundOpacity") var themeBackgroundOpacity: Double = 1.0
    @AppStorage("themeBackgroundBlur") var themeBackgroundBlur: Double = 0.0
    @AppStorage("themeBackgroundHoverOnly") var themeBackgroundHoverOnly = false

    @AppStorage("expandedPadding") var expandedPadding: Double = 16.0

    @AppStorage("enableAppleMusic") var enableAppleMusic = false
    @AppStorage("enableSpotify") var enableSpotify = false
    @AppStorage("enableChrome") var enableChrome = false
    @AppStorage("enableBrave") var enableBrave = false
    @AppStorage("enableEdge") var enableEdge = false
    @AppStorage("enableSafari") var enableSafari = false

    @AppStorage("plugin_spotify_queue_enabled") var spotifyQueueEnabled = false
    @AppStorage("plugin_spotify_playlists_enabled") var spotifyPlaylistsEnabled = false
    @AppStorage("plugin_pomodoro_timer_enabled") var pomodoroPluginEnabled = false
    @AppStorage("plugin_file_tray_enabled") var fileTrayPluginEnabled = false
    @AppStorage("pomodoro_show_notch_timer") var showPomodoroNotchTimer = true
    @AppStorage("pomodoro_show_time_text") var showPomodoroTimeText = false
    @AppStorage("pomodoro_show_timer_banner") var showPomodoroTimerBanner = true
    @AppStorage("pomodoro_show_mode_change_banner") var showPomodoroModeChangeBanner = true

    @State private var isShowingBanner = false
    @State private var bannerText: String = ""
    @State private var bannerIconName: String?
    @State private var bannerTintColor: Color = .white
    @State private var bannerTask: Task<Void, Never>? = nil
    @State private var isShowingTaskReminderBanner = false
    @State private var taskReminderBannerTitle = ""
    @State private var taskReminderBannerBody = ""
    @State private var taskReminderBannerTask: Task<Void, Never>? = nil
    @State private var isShowingLyricBanner = false
    @State private var currentLyricText: String = ""
    @State private var isFileDropTargeted = false
    @State private var fileDropCount = 0
    @State private var fileDragDetector: FileDragDetector?
    @State private var isPostFileDropExpansionSuppressed = false
    @State private var isFileDropLayoutLocked = false
    @State private var shouldRenderExpandedLayer = false
    @State private var expandedLayerRenderTask: Task<Void, Never>? = nil
    @State private var isHoveringNotch = false
    @State private var isPluginInteractionLocked = false

    @State private var cachedThemeImage: NSImage? = nil

    @State private var hoverTask: Task<Void, Never>? = nil

    @State private var localMediaKeyMonitor: Any?
    @State private var globalMediaKeyMonitor: Any?

    @State private var glowRotation: Double = 0.0
    @State private var glowOpacity: Double = 0.0
    @State private var skipDirection: Int = 1
    @State private var lastSongChangeTime: Date = Date.distantPast
    @State private var collapsedDisplayTime: Double = 0
    @State private var collapsedActiveLyricIndex: Int = 0
    private let collapsedPlaybackClockInterval: TimeInterval = 0.5
    private let fileDropTypes = FileDropTypeIdentifiers.all

    // ---------------------------------------------------------
    // ⚡️ THE BULLETPROOF NOTCH DETECTION
    // Agent apps sometimes get generic data from NSScreen.main.
    // This loops through EVERY connected display, finds the physical
    // camera notch, and grabs its exact pixel depth.
    // ---------------------------------------------------------
    var notchHeight: CGFloat {
        let actualNotchDepth = NSScreen.screens.map { $0.safeAreaInsets.top }.max() ?? 0

        // 3. A physical notch is always taller than 24px.
        // If it found one, use it. Otherwise, safely fall back to 32.
        return actualNotchDepth > 24 ? actualNotchDepth : 32
    }

    let bannerHeightAddon: CGFloat = 24
    let notchBlendRadius: CGFloat = 16
    let expandedRowSpacing: CGFloat = 6
    let playlistWidgetHeight: CGFloat = 144
    let pomodoroWidgetHeight: CGFloat = 160
    let playerWidgetHeightBuffer: CGFloat = 18

    private var shouldShowPomodoroCollapsedTimeText: Bool {
        pomodoroPluginEnabled && showPomodoroTimeText
    }

    private var pomodoroCollapsedTimeTextWidthAddon: CGFloat {
        shouldShowPomodoroCollapsedTimeText ? 72 : 0
    }

    var collapsedWidth: CGFloat {
        CGFloat(storedCollapsedWidth) + pomodoroCollapsedTimeTextWidthAddon
    }

    var activeWidgetsCount: Int {
        layoutWidgets.count
    }

    var expandedWidth: CGFloat {
        activeWidgetsCount <= 1 ? 340 : 540
    }

    var expandedHeight: CGFloat {
        expandedHeight(for: layoutWidgets)
    }

    private var showsCollapsedBanner: Bool {
        let hasMedia = nowPlaying.currentSong != "No Music" && nowPlaying.currentSong != "NOT_PLAYING"
        return isShowingBanner || shouldShowPomodoroTimerBanner || (isShowingLyricBanner && hasMedia)
    }

    private var currentCollapsedHeight: CGFloat {
        showsCollapsedBanner ? (notchHeight + bannerHeightAddon) : notchHeight
    }

    private var currentWidth: CGFloat {
        isExpanded ? expandedWidth : collapsedWidth
    }

    private var currentHeight: CGFloat {
        isExpanded ? expandedHeight : currentCollapsedHeight
    }

    private var isFileDropMode: Bool {
        fileTrayPluginEnabled && isFileDropTargeted
    }

    private var usesFileDropOnlyLayout: Bool {
        fileTrayPluginEnabled && (isFileDropTargeted || isFileDropLayoutLocked)
    }

    private var layoutWidgets: [NotchWidgetType] {
        usesFileDropOnlyLayout ? [.fileTray] : dashboardManager.activeWidgets
    }

    private var shouldRevealThemeBackground: Bool {
        !themeBackgroundHoverOnly || isHoveringNotch || isExpanded || usesFileDropOnlyLayout
    }

    private var themeLayerOpacity: Double {
        shouldRevealThemeBackground ? themeBackgroundOpacity : 0.0
    }

    private var fileDropExpandedWidth: CGFloat {
        340
    }

    private var fileDropExpandedHeight: CGFloat {
        expandedHeight(for: [.fileTray])
    }

    private func expandedHeight(for widgets: [NotchWidgetType]) -> CGFloat {
        if widgets.isEmpty { return notchHeight + CGFloat(expandedPadding) * 2 }

        let rows = widgets.chunked(into: 2)
        let pad = CGFloat(expandedPadding)
        var totalH: CGFloat = notchHeight + pad

        for row in rows {
            let isCompact = rowUsesCompactPlayerLayout(row)
            let playerH = playerWidgetHeight(isCompact: isCompact)

            var rowMaxH: CGFloat = 0
            for widget in row {
                rowMaxH = max(rowMaxH, expandedWidgetHeight(for: widget, playerHeight: playerH))
            }
            totalH += rowMaxH
        }

        totalH += CGFloat(max(0, rows.count - 1)) * expandedRowSpacing
        totalH += pad

        return totalH
    }

    var body: some View {
        let hasMedia = nowPlaying.currentSong != "No Music" && nowPlaying.currentSong != "NOT_PLAYING"

        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                // 1. BACKGROUND LAYER (Precise hover detection lives here)
                backgroundLayer(currentWidth: currentWidth, currentHeight: currentHeight)

                // 2. CONTENT LAYERS
                if !isFileDropMode {
                    collapsedLayer(hasMedia: hasMedia, currentCollapsedHeight: currentCollapsedHeight)
                }
                if shouldRenderExpandedLayer {
                    expandedLayer(expandedHeight: expandedHeight)
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .top)),
                                removal: .opacity
                            )
                        )
                }

                settingsButtonLayer
                taskReminderNativeBannerLayer
            }
            .frame(width: currentWidth, height: currentHeight, alignment: .top)
            .onHover { hovering in
                handleHoverState(hovering)
            }
            .onChange(of: currentWidth) { _, _ in
                NotificationCenter.default.post(name: NSNotification.Name("CenterAppWindow"), object: nil)
            }
            .contextMenu {
                Button(action: { SettingsWindowManager.shared.showSettings() }) {
                    Text("Settings")
                    Image(systemName: "gearshape")
                }
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Text("Quit WaveNotch")
                    Image(systemName: "power")
                }
            }
            .clipShape(DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: notchBlendRadius))
            .animation(
                isExpanded
                ? .spring(response: 0.42, dampingFraction: 0.88, blendDuration: 0.12)
                : .spring(response: 0.32, dampingFraction: 0.96, blendDuration: 0.1),
                value: isExpanded
            )
            .animation(.easeOut(duration: 0.18), value: shouldRenderExpandedLayer)
            .animation(.spring(response: 0.30, dampingFraction: 1.0, blendDuration: 0.1), value: showsCollapsedBanner)
            .animation(.spring(response: 0.28, dampingFraction: 0.9, blendDuration: 0.08), value: collapsedWidth)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(fileDropCatcherLayer)
        .opacity(isAppHidden ? 0 : 1)
        .allowsHitTesting(!isAppHidden)
        .onAppear {
            localMediaKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .systemDefined) { event in
                handleSystemKey(event: event)
                return event
            }
            globalMediaKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { event in
                handleSystemKey(event: event)
            }
            registerKeyboardShortcuts()
            loadThemeImage()
            setupFileDragDetector()
            nowPlaying.setNotchExpanded(isExpanded)
            updateHardwareHUDVisibility()
        }
        .onDisappear {
            if let keyLocal = localMediaKeyMonitor { NSEvent.removeMonitor(keyLocal) }
            if let keyGlobal = globalMediaKeyMonitor { NSEvent.removeMonitor(keyGlobal) }
            fileDragDetector?.stopMonitoring()
            fileDragDetector = nil
            expandedLayerRenderTask?.cancel()
            expandedLayerRenderTask = nil
            HardwareHUDManager.shared.setDashboardVisible(false)
        }
        .onChange(of: themeBackgroundImagePath) { _, _ in
            loadThemeImage()
        }
        .onChange(of: themeBackgroundType) { _, _ in
            loadThemeImage()
        }
        .onChange(of: isExpanded) { _, expanded in
            nowPlaying.setNotchExpanded(expanded)
            updateHardwareHUDVisibility()
            updateExpandedLayerRendering(isExpanded: expanded)

            if !expanded {
                updateLyricBanner()
                currentTab = .player
            } else {
                guard !isFileDropMode else { return }
                dashboardManager.refreshWidgets()
                // ⚡️ REFETCH GOOGLE EVENTS: Ensure schedule is fresh on expand
                if GoogleCalendarManager.shared.isAuthenticated {
                    GoogleCalendarManager.shared.fetchTodaysEvents()
                }

                // ⚡️ REFETCH SPOTIFY: Ensure data isn't stuck in "Fetching..."
                if !SpotifyAuthManager.shared.accessToken.isEmpty {
                    if SpotifyAuthManager.shared.currentQueueItems.isEmpty {
                        SpotifyAuthManager.shared.fetchQueue()
                    }
                    if SpotifyAuthManager.shared.playlists.isEmpty {
                        SpotifyAuthManager.shared.fetchPlaylists()
                    }
                }
            }
        }
        .onChange(of: nowPlaying.currentSong) { _, newSong in
            handleSongChange(newSong)
        }
        .onChange(of: dashboardManager.activeWidgets) { _, _ in
            updateHardwareHUDVisibility()
        }
        .task {
            var lastPlaybackUpdate = Date()
            while !Task.isCancelled {
                let loopInterval = await MainActor.run { contentLoopInterval }
                try? await Task.sleep(nanoseconds: UInt64(loopInterval * 1_000_000_000))
                await MainActor.run {
                    let now = Date()
                    let elapsed = min(max(now.timeIntervalSince(lastPlaybackUpdate), 0), 2.0)
                    lastPlaybackUpdate = now

                    if shouldAdvanceCollapsedPlaybackClock {
                        collapsedDisplayTime = min(max(collapsedDisplayTime + elapsed, 0), max(nowPlaying.duration, 1))
                        updateCollapsedActiveLyricIndex()
                        updateLyricBanner()
                    }

                    guard shouldSampleHoverFallback else { return }

                    if isFileDropTargeted {
                        return
                    }

                    let mouseLoc = NSEvent.mouseLocation
                    guard let screen = screenForHover(at: mouseLoc) else {
                        if isHoveringNotch {
                            isHoveringNotch = false
                        }
                        return
                    }

                    let currentW = isExpanded ? expandedWidth : collapsedWidth
                    let currentH = isExpanded ? expandedHeight : currentCollapsedHeight

                    // Reconstruct the notch window frame in screen coordinates
                    let panelRect = CGRect(
                        x: screen.frame.midX - currentW / 2,
                        y: screen.frame.maxY - currentH,
                        width: currentW,
                        height: currentH
                    )

                    handleHoverState(panelRect.contains(mouseLoc))
                }
            }
        }
        .onChange(of: nowPlaying.currentSong) { _, _ in
            syncCollapsedPlaybackClock(from: nowPlaying.currentTime, force: true)
        }
        .onChange(of: nowPlaying.currentTime) { _, newTime in
            syncCollapsedPlaybackClock(from: newTime, force: !nowPlaying.isPlaying)
        }
        .onChange(of: nowPlaying.duration) { _, _ in
            syncCollapsedPlaybackClock(from: min(collapsedDisplayTime, max(nowPlaying.duration, 1)), force: true)
        }
        .onChange(of: nowPlaying.activeLyricIndex) { _, _ in
            syncCollapsedPlaybackClock(from: nowPlaying.currentTime)
        }
        .onChange(of: showBannerLyrics) { _, _ in updateLyricBanner() }
        .onChange(of: nowPlaying.lyrics) { _, _ in
            updateCollapsedActiveLyricIndex()
            updateLyricBanner()
        }
        .onChange(of: nowPlaying.currentSongLyricOffset) { _, _ in
            updateCollapsedActiveLyricIndex()
            updateLyricBanner()
        }
        .onChange(of: nowPlaying.isPlaying) { _, newState in
            updateLyricBanner()
            guard showBannerOnControl else { return }
            guard nowPlaying.currentSong != "No Music" && nowPlaying.currentSong != "NOT_PLAYING" else { return }
            guard Date().timeIntervalSince(lastSongChangeTime) > 0.5 else { return }
            triggerBanner(text: newState ? "Resumed" : "Paused", duration: 1.5)
        }
        .onReceive(NotificationCenter.default.publisher(for: .fileTrayDropTargetChanged)) { notification in
            let targeted = notification.userInfo?["isTargeted"] as? Bool ?? false
            let count = notification.userInfo?["count"] as? Int ?? 0
            withAnimation(.spring(response: 0.28, dampingFraction: 0.74)) {
                isFileDropTargeted = targeted
                fileDropCount = count
                if targeted {
                    isPostFileDropExpansionSuppressed = false
                    isFileDropLayoutLocked = true
                    prepareForFileDrop()
                } else if !isPostFileDropExpansionSuppressed {
                    isFileDropLayoutLocked = false
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .notchPluginInteractionLockChanged)) { notification in
            let locked = notification.userInfo?["isLocked"] as? Bool ?? false
            handlePluginInteractionLock(locked)
        }
        .onChange(of: isFileDropTargeted) { _, targeted in
            if targeted {
                isFileDropLayoutLocked = true
                prepareForFileDrop()
            } else if !isPostFileDropExpansionSuppressed {
                isFileDropLayoutLocked = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .fileTrayDropCompleted)) { notification in
            let count = notification.userInfo?["count"] as? Int ?? 0
            finishFileDrop(count: count)
        }
        .onReceive(NotificationCenter.default.publisher(for: .pomodoroSessionCompleted)) { notification in
            showPomodoroCompletionBanner(from: notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: .taskReminderBannerRequested)) { notification in
            showTaskReminderBanner(from: notification)
        }
        .edgesIgnoringSafeArea(.all)
    }

    @ViewBuilder
    private func backgroundLayer(currentWidth: CGFloat, currentHeight: CGFloat) -> some View {
        DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: notchBlendRadius)
            .fill(themeBackgroundType == "color" && !themeBackgroundHoverOnly ? (Color(hex: themeBackgroundColorHex) ?? .black) : .black)
            .opacity(themeBackgroundType == "color" && !themeBackgroundHoverOnly ? themeBackgroundOpacity : 1.0)
            .overlay(
                Group {
                    if themeBackgroundType == "color" && themeBackgroundHoverOnly {
                        (Color(hex: themeBackgroundColorHex) ?? .black)
                            .frame(width: currentWidth, height: currentHeight)
                            .opacity(themeLayerOpacity)
                            .clipShape(DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: notchBlendRadius))
                    } else if themeBackgroundType == "preset" {
                        ThemePresetBackground(presetID: themePresetID)
                            .frame(width: currentWidth, height: currentHeight)
                            .opacity(themeLayerOpacity)
                            .clipShape(DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: notchBlendRadius))
                    } else if themeBackgroundType == "image", let nsImage = cachedThemeImage {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: currentWidth, height: currentHeight)
                            .opacity(themeLayerOpacity)
                            .blur(radius: themeBackgroundBlur)
                            .clipShape(DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: notchBlendRadius))
                    }
                }
                .animation(.easeInOut(duration: 0.22), value: shouldRevealThemeBackground)
            )
            .frame(width: currentWidth, height: currentHeight)
            .contentShape(DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: notchBlendRadius))
            .onTapGesture(count: 2) {
                SettingsWindowManager.shared.showSettings()
            }
            .overlay(
                DynamicNotchShape(cornerRadius: isExpanded ? 24 : 16, blendRadius: notchBlendRadius)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: nowPlaying.artworkDominantColor, location: 0.1),
                                .init(color: .white, location: 0.12),
                                .init(color: .clear, location: 0.131)
                            ]),
                            center: .center,
                            angle: .degrees(glowRotation)
                        ),
                        lineWidth: 2.5
                    )
                    .opacity(glowOpacity)
                    .shadow(color: nowPlaying.artworkDominantColor.opacity(glowOpacity), radius: 7, x: 0, y: 0)
                    .allowsHitTesting(false)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 12, y: 6)
            .zIndex(1)
    }

    @ViewBuilder
    private var fileDropCatcherLayer: some View {
        if fileTrayPluginEnabled {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onDrop(
                    of: fileDropTypes,
                    delegate: FileTrayRootDropDelegate(
                        isTargeted: $isFileDropTargeted,
                        fileDropCount: $fileDropCount,
                        prepare: prepareForFileDrop
                    )
                )
        }
    }

    @ViewBuilder
    private var taskReminderNativeBannerLayer: some View {
        if isExpanded && isShowingTaskReminderBanner {
            HStack(spacing: 10) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.yellow)
                    .frame(width: 32, height: 32)
                    .background(Color.yellow.opacity(0.18))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(taskReminderBannerTitle)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(taskReminderBannerBody)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.58))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text("now")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.45))
            }
            .padding(.horizontal, 12)
            .frame(width: max(220, currentWidth - 44), height: 48)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.66))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.28), radius: 14, x: 0, y: 8)
            .padding(.top, notchHeight + 8)
            .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.96, anchor: .top)))
            .zIndex(20)
        }
    }

    @ViewBuilder
    private var settingsButtonLayer: some View {
        if isExpanded && showSettingsButton && !usesFileDropOnlyLayout {
            HStack {
                Spacer()
                Button(action: { SettingsWindowManager.shared.showSettings() }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
                .frame(width: 24, height: 24)
            }
            .padding(.trailing, 20)
            .padding(.top, 10)
            .zIndex(4)
        }
    }

    @ViewBuilder
    private func collapsedLayer(hasMedia: Bool, currentCollapsedHeight: CGFloat) -> some View {
        let showTimerIcon = pomodoroPluginEnabled && showPomodoroNotchTimer
        let showTimerText = shouldShowPomodoroCollapsedTimeText
        let showTimerBanner = shouldShowPomodoroTimerBanner

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ZStack {
                    if showTimerIcon {
                        pomodoroCollapsedProgressIcon
                    } else if hasMedia && nowPlaying.artworkURL != nil {
                        AsyncImage(url: nowPlaying.artworkURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: { Color.gray.opacity(0.3) }
                            .frame(width: 20, height: 20)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .id(nowPlaying.currentSong)
                            .transition(.panRotate(direction: skipDirection))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.white.opacity(0.1))
                            Image(systemName: "music.note")
                                .foregroundColor(nowPlaying.isPlaying ? .white : .gray)
                                .font(.system(size: 10, weight: .bold))
                        }
                        .frame(width: 20, height: 20)
                    }
                }
                .frame(width: 24, alignment: .leading)

                Spacer()

                if showTimerText {
                    Text(pomodoroTimer.timeText)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(pomodoroTimer.mode.color)
                        .frame(width: 56, alignment: .trailing)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pomodoroTimer.timeText)
                } else {
                    WaveformView(isPlaying: nowPlaying.isPlaying, color: nowPlaying.artworkDominantColor)
                        .frame(width: 24, alignment: .trailing)
                }
            }
            .padding(.horizontal, 24)
            .frame(height: notchHeight)

            if showsCollapsedBanner {
                ZStack {
                    if isShowingBanner {
                        HStack(spacing: 6) {
                            if let bannerIconName {
                                Image(systemName: bannerIconName)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(bannerTintColor)
                            }

                            MarqueeText(text: bannerText, font: .system(size: 12, weight: .bold), alignment: .center)
                                .foregroundColor(bannerIconName == nil ? nowPlaying.artworkDominantColor : .white)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .id("banner_\(bannerIconName ?? "none")_\(bannerText)")
                    } else if showTimerBanner {
                        HStack(spacing: 6) {
                            Image(systemName: pomodoroTimer.pendingTransition == nil ? "timer" : "bell.badge.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(pomodoroBannerText)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: pomodoroTimer.timeText)
                                .monospacedDigit()
                            Text(pomodoroTimer.roundText)
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.45))
                        }
                        .foregroundColor(pomodoroTimer.pendingTransition?.completedMode.color ?? pomodoroTimer.mode.color)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    } else if isShowingLyricBanner {
                        MarqueeText(text: currentLyricText, font: .system(size: 12, weight: .bold), alignment: .center)
                            .foregroundColor(nowPlaying.artworkDominantColor)
                            .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity.combined(with: .move(edge: .leading))))
                            .id("lyric_\(currentLyricText)")
                    }
                }
                .frame(height: bannerHeightAddon)
                .padding(.horizontal, 24)
                .clipped()
            }
        }
        .frame(width: collapsedWidth, height: currentCollapsedHeight)
        .opacity(isExpanded ? 0 : 1)
        .scaleEffect(isExpanded ? 0.95 : 1.0, anchor: .top)
        .allowsHitTesting(!isExpanded)
        .onTapGesture {
            guard !isPostFileDropExpansionSuppressed else { return }

            if !isExpanded {
                isPostFileDropExpansionSuppressed = false
                isFileDropLayoutLocked = false
                prepareExpandedLayerForExpansion()
                isExpanded = true
                isShowingBanner = false
                isShowingLyricBanner = false
                bannerTask?.cancel()
            }
        }
        .zIndex(2)
    }

    private var shouldShowPomodoroNotchTimer: Bool {
        pomodoroPluginEnabled && showPomodoroNotchTimer
    }

    private var shouldShowPomodoroTimerBanner: Bool {
        pomodoroPluginEnabled && !isExpanded && showPomodoroTimerBanner && pomodoroTimer.isRunning
    }

    private var pomodoroBannerText: String {
        return "\(pomodoroTimer.mode.title) \(pomodoroTimer.timeText)"
    }

    private var pomodoroCollapsedProgressIcon: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: 2)
            Circle()
                .trim(from: 0, to: max(0.001, pomodoroTimer.progress))
                .stroke(pomodoroTimer.mode.color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "clock.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(width: 22, height: 22)
    }

    private var shouldAdvanceCollapsedPlaybackClock: Bool {
        !isExpanded && nowPlaying.isPlaying && showBannerLyrics && !nowPlaying.lyrics.isEmpty
    }

    private var shouldPollHoverFallback: Bool {
        isExpanded || isHoveringNotch || isPluginInteractionLocked || isPostFileDropExpansionSuppressed || isFileDropTargeted || hoverTask != nil
    }

    private var shouldSampleHoverFallback: Bool {
        shouldPollHoverFallback || enableHoverToExpand
    }

    private var contentLoopInterval: TimeInterval {
        if shouldPollHoverFallback { return 0.35 }
        if enableHoverToExpand { return 0.75 }
        if shouldAdvanceCollapsedPlaybackClock { return collapsedPlaybackClockInterval }
        return 4.0
    }

    private func handleHoverState(_ hovering: Bool) {
        if isHoveringNotch != hovering {
            isHoveringNotch = hovering
        }

        if isFileDropTargeted {
            return
        }

        if isPluginInteractionLocked {
            hoverTask?.cancel()
            hoverTask = nil
            if !isExpanded {
                prepareExpandedLayerForExpansion()
                isExpanded = true
            }
            return
        }

        if isPostFileDropExpansionSuppressed {
            hoverTask?.cancel()
            hoverTask = nil
            if isExpanded {
                isExpanded = false
            }
            if !hovering {
                isPostFileDropExpansionSuppressed = false
                isFileDropLayoutLocked = false
            }
            return
        }

        if hovering {
            scheduleHoverExpansionIfNeeded()
        } else {
            hoverTask?.cancel()
            hoverTask = nil
            if isExpanded {
                isExpanded = false
            }
        }
    }

    private func handlePluginInteractionLock(_ locked: Bool) {
        guard isPluginInteractionLocked != locked else { return }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            isPluginInteractionLocked = locked
            hoverTask?.cancel()
            hoverTask = nil

            if locked {
                prepareExpandedLayerForExpansion()
                isExpanded = true
                isShowingBanner = false
                isShowingLyricBanner = false
                bannerTask?.cancel()
            } else if !isHoveringNotch && !isFileDropTargeted && !isPostFileDropExpansionSuppressed {
                isExpanded = false
            }
        }
    }

    private func scheduleHoverExpansionIfNeeded() {
        guard enableHoverToExpand, !isExpanded, hoverTask == nil else { return }

        hoverTask = Task {
            if hoverDelay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(hoverDelay * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !isPostFileDropExpansionSuppressed else { return }
                guard isHoveringNotch else {
                    hoverTask = nil
                    return
                }
                prepareExpandedLayerForExpansion()
                isExpanded = true
                hoverTask = nil
                isShowingBanner = false
                isShowingLyricBanner = false
                bannerTask?.cancel()
            }
        }
    }

    private func updateHardwareHUDVisibility() {
        let isVisible = isExpanded && layoutWidgets.contains(.hardwareHUD)
        HardwareHUDManager.shared.setDashboardVisible(isVisible)
    }

    private func expandedWidgetHeight(for widget: NotchWidgetType, playerHeight: CGFloat) -> CGFloat {
        switch widget {
        case .player: return playerHeight
        case .turntable, .cassette: return 196
        case .spotifyQueue, .youtubeQueue: return 250
        case .spotifyPlaylists, .youtubePlaylists: return playlistWidgetHeight
        case .pomodoro: return pomodoroWidgetHeight
        case .clipboard, .fileTray: return 220
        case .tasks: return 270
        case .kaomoji: return 220
        case .weather: return 132
        case .hardwareHUD: return 174
        case .bluetoothBattery: return 174
        case .screenCapture: return 174
        default: return 160
        }
    }

    private func playerWidgetHeight(isCompact: Bool) -> CGFloat {
        let hasMedia = nowPlaying.currentSong != "No Music" && nowPlaying.currentSong != "NOT_PLAYING"
        let topRowHeight: CGFloat = 40
        let controlsHeight: CGFloat = hasMedia ? 38 : 0
        let progressHeight: CGFloat = hasMedia ? 20 : 0
        let lyricsHeight: CGFloat = (hasMedia && !nowPlaying.lyrics.isEmpty && showLyrics) ? (8 + CGFloat(visibleLyricLines) * 26.0) : 0
        let verticalPadding: CGFloat = 24

        return topRowHeight + controlsHeight + progressHeight + lyricsHeight + verticalPadding + playerWidgetHeightBuffer
    }

    private func rowUsesCompactPlayerLayout(_ row: [NotchWidgetType]) -> Bool {
        row.count > 1
    }

    private func updateExpandedLayerRendering(isExpanded expanded: Bool) {
        expandedLayerRenderTask?.cancel()
        expandedLayerRenderTask = nil

        if expanded {
            prepareExpandedLayerForExpansion()
            return
        }

        expandedLayerRenderTask = Task {
            try? await Task.sleep(nanoseconds: 320_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard !isExpanded else { return }
                shouldRenderExpandedLayer = false
                expandedLayerRenderTask = nil
            }
        }
    }

    private func prepareExpandedLayerForExpansion() {
        expandedLayerRenderTask?.cancel()
        expandedLayerRenderTask = nil
        shouldRenderExpandedLayer = true
    }

    @ViewBuilder
    private func expandedLayer(expandedHeight: CGFloat) -> some View {
        let widgets = layoutWidgets
        let pad = CGFloat(expandedPadding)
        let sideInset = notchBlendRadius + pad
        let contentWidth = expandedWidth - (sideInset * 2)
        let splitRowWidth = contentWidth - expandedRowSpacing

        VStack(spacing: 0) {
            if widgets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 32))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No widgets enabled.")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.gray)
                    Text("Go to Settings > Layout to enable plugins.")
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.8))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // ⚡️ DYNAMIC ROW-BASED LAYOUT
                let rows = widgets.chunked(into: 2)

                VStack(spacing: expandedRowSpacing) {
                    ForEach(0..<rows.count, id: \.self) { rowIndex in
                        let row = rows[rowIndex]
                        let isCompact = rowUsesCompactPlayerLayout(row)
                        let playerH = playerWidgetHeight(isCompact: isCompact)

                        let rowMaxH = row
                            .map { expandedWidgetHeight(for: $0, playerHeight: playerH) }
                            .max() ?? playerH

                        HStack(alignment: .center, spacing: expandedRowSpacing) {
                            if row.count == 2 {
                                let w1 = row[0]
                                let w2 = row[1]

                                // Ratios: queue-style widgets are always 0.4 (minor), all others split 1:1.
                                let r1: CGFloat = {
                                    let w1UsesNarrowWidth = w1 == .spotifyQueue || w1 == .turntable
                                    let w2UsesNarrowWidth = w2 == .spotifyQueue || w2 == .turntable

                                    if w1UsesNarrowWidth && !w2UsesNarrowWidth { return 0.4 }
                                    if w2UsesNarrowWidth && !w1UsesNarrowWidth { return 0.6 }
                                    return 0.5
                                }()
                                let r2 = 1.0 - r1

                                WidgetFactoryView(
                                    widgetType: w1,
                                    nowPlaying: nowPlaying,
                                    expandedWidth: splitRowWidth * r1,
                                    isCompact: true,
                                    skipDirection: $skipDirection,
                                    glowOpacity: $glowOpacity,
                                    onSwipe: { forward in self.executeSkip(forward: forward) }
                                )
                                .frame(width: splitRowWidth * r1, height: rowMaxH)
                                .clipped(when: w1 != .player)

                                WidgetFactoryView(
                                    widgetType: w2,
                                    nowPlaying: nowPlaying,
                                    expandedWidth: splitRowWidth * r2,
                                    isCompact: true,
                                    skipDirection: $skipDirection,
                                    glowOpacity: $glowOpacity,
                                    onSwipe: { forward in self.executeSkip(forward: forward) }
                                )
                                .frame(width: splitRowWidth * r2, height: rowMaxH)
                                .clipped(when: w2 != .player)

                            } else {
                                // Single widget row (e.g. last item in odd-count list)
                                WidgetFactoryView(
                                    widgetType: row[0],
                                    nowPlaying: nowPlaying,
                                    expandedWidth: contentWidth,
                                    isCompact: isCompact,
                                    skipDirection: $skipDirection,
                                    glowOpacity: $glowOpacity,
                                    onSwipe: { forward in self.executeSkip(forward: forward) }
                                )
                                .frame(width: contentWidth, height: rowMaxH)
                                .clipped(when: row[0] != .player)
                            }
                        }
                        .frame(width: contentWidth)
                    }
                }
            }
        }
        .padding(.horizontal, sideInset)
        .padding(.top, notchHeight + pad)
        .padding(.bottom, pad)
        .frame(width: expandedWidth, height: expandedHeight, alignment: .top)
        .opacity(isExpanded ? 1 : 0)
        .scaleEffect(isExpanded ? 1.0 : 0.95, anchor: .top)
        .allowsHitTesting(isExpanded)
        .zIndex(3)
    }

    private func executeSkip(forward: Bool) {
        skipDirection = forward ? 1 : -1
        if forward {
            nowPlaying.skipForward()
        } else {
            nowPlaying.skipBackward()
        }
        triggerBanner(text: forward ? "Skipped Forward" : "Skipped Back", duration: 1.5)
    }

    private func setupFileDragDetector() {
        fileDragDetector?.stopMonitoring()

        let detector = FileDragDetector {
            guard fileTrayPluginEnabled else { return nil }
            return fileDropRegion()
        }

        detector.onDragEntersRegion = {
            DispatchQueue.main.async {
                postFileDropTargetChanged(true, count: max(fileDropCount, 1))
                withAnimation(.spring(response: 0.28, dampingFraction: 0.74)) {
                    fileDropCount = max(fileDropCount, 1)
                    isFileDropTargeted = true
                    prepareForFileDrop()
                }
            }
        }

        detector.onDragExitsRegion = {
            DispatchQueue.main.async {
                postFileDropTargetChanged(false, count: 0)
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    isFileDropTargeted = false
                }
            }
        }

        detector.onDragEnds = {
            DispatchQueue.main.async {
                postFileDropTargetChanged(false, count: 0)
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    isFileDropTargeted = false
                }
            }
        }

        detector.startMonitoring()
        fileDragDetector = detector
    }

    private func prepareForFileDrop() {
        guard fileTrayPluginEnabled else { return }
        isPostFileDropExpansionSuppressed = false
        isFileDropLayoutLocked = true
        if !isExpanded {
            prepareExpandedLayerForExpansion()
            isExpanded = true
        }
        isShowingBanner = false
        isShowingLyricBanner = false
        bannerTask?.cancel()
        hoverTask?.cancel()
        hoverTask = nil
    }

    private func finishFileDrop(count: Int) {
        hoverTask?.cancel()
        hoverTask = nil

        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            isFileDropTargeted = false
            fileDropCount = 0
            isExpanded = false
            isFileDropLayoutLocked = true
            isPostFileDropExpansionSuppressed = true
        }

        triggerBanner(text: count == 1 ? "File added to tray" : "\(count) files added to tray", duration: 1.5)
    }

    private func fileDropRegion() -> CGRect? {
        guard fileTrayPluginEnabled else { return nil }
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = screenForHover(at: mouseLocation) else { return nil }

        let width = max(isExpanded ? expandedWidth : fileDropExpandedWidth, fileDropExpandedWidth)
        let height = max(isExpanded ? expandedHeight : fileDropExpandedHeight, fileDropExpandedHeight)
        return CGRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - height,
            width: width,
            height: height
        )
        .insetBy(dx: -32, dy: -24)
    }

    private func postFileDropTargetChanged(_ targeted: Bool, count: Int) {
        var userInfo: [String: Any] = ["isTargeted": targeted, "count": count]
        if targeted,
           let screen = screenForHover(at: NSEvent.mouseLocation) {
            userInfo["screenFrame"] = NSValue(rect: screen.frame)
        }

        NotificationCenter.default.post(
            name: .fileTrayDropTargetChanged,
            object: nil,
            userInfo: userInfo
        )
    }

    private func registerKeyboardShortcuts() {
        KeyboardShortcuts.onKeyDown(for: .toggleAppVisibility) {
            isAppHidden.toggle()
        }
        KeyboardShortcuts.onKeyDown(for: .toggleLiveLyrics) {
            showLyrics.toggle()
        }
        KeyboardShortcuts.onKeyDown(for: .toggleBannerLyrics) {
            showBannerLyrics.toggle()
            updateLyricBanner()
        }
        KeyboardShortcuts.onKeyDown(for: .toggleBanner) {
            showBannerOnControl.toggle()
        }
        KeyboardShortcuts.onKeyDown(for: .increaseOffset) {
            nowPlaying.adjustCurrentSongLyricOffset(by: 0.5)
            triggerBanner(text: "Lyrics Earlier \(formatSignedOffset(nowPlaying.currentSongLyricOffset))", duration: 1.2)
        }
        KeyboardShortcuts.onKeyDown(for: .decreaseOffset) {
            nowPlaying.adjustCurrentSongLyricOffset(by: -0.5)
            triggerBanner(text: "Lyrics Later \(formatSignedOffset(nowPlaying.currentSongLyricOffset))", duration: 1.2)
        }
        KeyboardShortcuts.onKeyDown(for: .increaseLines) {
            visibleLyricLines = min(5, visibleLyricLines == 1 ? 3 : visibleLyricLines + 2)
        }
        KeyboardShortcuts.onKeyDown(for: .decreaseLines) {
            visibleLyricLines = max(1, visibleLyricLines == 5 ? 3 : visibleLyricLines - 2)
        }
        KeyboardShortcuts.onKeyDown(for: .increaseDelay) {
            hoverDelay = min(3.0, hoverDelay + 0.1)
        }
        KeyboardShortcuts.onKeyDown(for: .decreaseDelay) {
            hoverDelay = max(0.0, hoverDelay - 0.1)
        }
    }

    private func formatSignedOffset(_ value: Double) -> String {
        value == 0.0 ? "0.0s" : String(format: "%+.1fs", value)
    }

    private func handleSongChange(_ newSong: String) {
        guard newSong != "No Music" else { return }
        guard newSong != "NOT_PLAYING" else { return }

        if showGlowEffect {
            glowOpacity = 0.0
            glowRotation = 0.0
            withAnimation(.easeIn(duration: 0.35)) { glowOpacity = 1.0 }
            withAnimation(.easeInOut(duration: 2.4)) { glowRotation = 360 }
            withAnimation(.easeOut(duration: 0.85).delay(1.65)) { glowOpacity = 0.0 }
        }

        if showSongChangeBanner {
            triggerBanner(text: newSong, duration: bannerDuration)
        }
    }

    private func loadThemeImage() {
        guard themeBackgroundType == "image", !themeBackgroundImagePath.isEmpty else {
            cachedThemeImage = nil
            return
        }

        let path = themeBackgroundImagePath
        DispatchQueue.global(qos: .userInitiated).async {
            let url = URL(fileURLWithPath: path)
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else { return }

            // ⚡️ DOWN-SAMPLE MASSIVE IMAGES
            // Large 4K images cause massive rendering lag during fast layout updates in the Notch.
            // Using CGImageSource is thread-safe and highly optimized, avoiding priority inversions.
            let options: [CFString: Any] = [
                kCGImageSourceThumbnailMaxPixelSize: 1200,
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true
            ]

            if let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) {
                let newImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                DispatchQueue.main.async { self.cachedThemeImage = newImage }
            } else if let image = NSImage(contentsOfFile: path) {
                DispatchQueue.main.async { self.cachedThemeImage = image }
            }
        }
    }

    private func handleSystemKey(event: NSEvent) {
        if event.subtype.rawValue == 8 {
            let data = event.data1
            let keyCode = (data & 0xFFFF0000) >> 16
            let keyFlags = (data & 0x0000FFFF)
            let keyState = (((keyFlags & 0xFF00) >> 8)) == 0xA

            if keyState {
                if keyCode == 19 { skipDirection = -1 }
                else if keyCode == 20 { skipDirection = 1 }
            }
        }
    }

    private func updateLyricBanner() {
        guard showBannerLyrics, !isExpanded, nowPlaying.isPlaying, !nowPlaying.lyrics.isEmpty, collapsedActiveLyricIndex >= 0, collapsedActiveLyricIndex < nowPlaying.lyrics.count else {
            if isShowingLyricBanner {
                withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) {
                    isShowingLyricBanner = false
                }
            }
            return
        }
        let newLyric = nowPlaying.lyrics[collapsedActiveLyricIndex].text
        if newLyric.trimmingCharacters(in: .whitespaces).isEmpty {
            if isShowingLyricBanner {
                withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) {
                    isShowingLyricBanner = false
                }
            }
        } else if currentLyricText != newLyric || !isShowingLyricBanner {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
                currentLyricText = newLyric
                isShowingLyricBanner = true
            }
        }
    }

    private func syncCollapsedPlaybackClock(from managerTime: Double, force: Bool = false) {
        let clampedTime = min(max(managerTime, 0), max(nowPlaying.duration, 1))
        if force || abs(collapsedDisplayTime - clampedTime) > 1.5 {
            collapsedDisplayTime = clampedTime
            updateCollapsedActiveLyricIndex()
            updateLyricBanner()
        }
    }

    private func updateCollapsedActiveLyricIndex() {
        guard !nowPlaying.lyrics.isEmpty else {
            if collapsedActiveLyricIndex != 0 {
                collapsedActiveLyricIndex = 0
            }
            return
        }

        let globalOffset = UserDefaults.standard.double(forKey: "globalLyricOffset")
        let adjustedTime = collapsedDisplayTime + 0.05 + globalOffset + nowPlaying.currentSongLyricOffset
        let nextIndex = collapsedLyricIndex(for: adjustedTime)
        if collapsedActiveLyricIndex != nextIndex {
            collapsedActiveLyricIndex = nextIndex
        }
    }

    private func collapsedLyricIndex(for adjustedTime: Double) -> Int {
        guard !nowPlaying.lyrics.isEmpty else { return 0 }

        var index = min(max(collapsedActiveLyricIndex, 0), nowPlaying.lyrics.count - 1)
        if nowPlaying.lyrics[index].time <= adjustedTime {
            while index + 1 < nowPlaying.lyrics.count, nowPlaying.lyrics[index + 1].time <= adjustedTime {
                index += 1
            }
        } else {
            while index > 0, nowPlaying.lyrics[index].time > adjustedTime {
                index -= 1
            }
        }
        return index
    }

    private func showPomodoroCompletionBanner(from notification: Notification) {
        guard pomodoroPluginEnabled, showPomodoroModeChangeBanner else { return }

        let completedRaw = notification.userInfo?["completedMode"] as? String
        let nextRaw = notification.userInfo?["nextMode"] as? String
        let completedTitle = completedRaw.flatMap(PomodoroMode.init(rawValue:))?.title ?? "Pomodoro"
        let nextTitle = nextRaw.flatMap(PomodoroMode.init(rawValue:))?.title ?? "next session"

        triggerBanner(text: "\(completedTitle) complete - \(nextTitle) ready", duration: 3.0)
    }

    private func showTaskReminderBanner(from notification: Notification) {
        let title = notification.userInfo?["title"] as? String ?? "Reminder"
        let body = notification.userInfo?["body"] as? String ?? "Reminder due now."

        if isExpanded {
            taskReminderBannerTitle = title
            taskReminderBannerBody = body
            taskReminderBannerTask?.cancel()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                isShowingTaskReminderBanner = true
            }
            taskReminderBannerTask = Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.18)) {
                        isShowingTaskReminderBanner = false
                    }
                    taskReminderBannerTask = nil
                }
            }
        } else {
            triggerBanner(text: title, duration: 4.0, iconName: "bell.badge.fill", tint: .yellow)
        }
    }

    private func triggerBanner(text: String, duration: Double, iconName: String? = nil, tint: Color = .white) {
        if !isExpanded {
            bannerText = text
            bannerIconName = iconName
            bannerTintColor = tint
            isShowingLyricBanner = false
            withAnimation(.spring(response: 0.3, dampingFraction: 1.0)) { isShowingBanner = true }

            let sleepTime = UInt64(duration * 1_000_000_000)
            bannerTask?.cancel()
            bannerTask = Task {
                try? await Task.sleep(nanoseconds: sleepTime)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation { isShowingBanner = false }
                    bannerIconName = nil
                    updateLyricBanner()
                }
            }
        }
    }

    private func screenForHover(at location: NSPoint) -> NSScreen? {
        NSScreen.screens.first(where: { $0.frame.contains(location) }) ?? NSScreen.main ?? NSScreen.screens.first
    }
}

private struct FileTrayRootDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool
    @Binding var fileDropCount: Int
    let prepare: () -> Void

    func validateDrop(info: DropInfo) -> Bool {
        !providers(from: info).isEmpty
    }

    func dropEntered(info: DropInfo) {
        let providers = providers(from: info)
        guard !providers.isEmpty else { return }

        fileDropCount = max(providers.count, 1)
        isTargeted = true
        prepare()
        postTargeted(true, count: fileDropCount)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard !providers(from: info).isEmpty else {
            return DropProposal(operation: .cancel)
        }

        prepare()
        return DropProposal(operation: .copy)
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
        fileDropCount = 0
        postTargeted(false, count: 0)
    }

    func performDrop(info: DropInfo) -> Bool {
        let providers = providers(from: info)
        guard !providers.isEmpty else {
            isTargeted = false
            fileDropCount = 0
            postTargeted(false, count: 0)
            return false
        }

        let accepted = FileTrayManager.shared.add(from: providers)
        if accepted {
            NotificationCenter.default.post(
                name: .fileTrayDropCompleted,
                object: nil,
                userInfo: ["count": providers.count]
            )
        } else {
            isTargeted = false
            fileDropCount = 0
            postTargeted(false, count: 0)
        }
        return accepted
    }

    private func providers(from info: DropInfo) -> [NSItemProvider] {
        info.itemProviders(for: FileDropTypeIdentifiers.all)
    }

    private func postTargeted(_ targeted: Bool, count: Int) {
        var userInfo: [String: Any] = ["isTargeted": targeted, "count": count]
        if targeted,
           let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) {
            userInfo["screenFrame"] = NSValue(rect: screen.frame)
        }

        NotificationCenter.default.post(
            name: .fileTrayDropTargetChanged,
            object: nil,
            userInfo: userInfo
        )
    }
}

struct PanRotateModifier: ViewModifier {
    let offset: CGFloat
    let angle: Double
    let opacity: Double
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0))
            .scaleEffect(scale)
            .opacity(opacity)
    }
}

extension AnyTransition {
    static func panRotate(direction: Int) -> AnyTransition {
        return .asymmetric(
            insertion: .modifier(
                active: PanRotateModifier(offset: CGFloat(direction * 25), angle: Double(direction * 60), opacity: 0, scale: 0.9),
                identity: PanRotateModifier(offset: 0, angle: 0, opacity: 1, scale: 1.0)
            ),
            removal: .modifier(
                active: PanRotateModifier(offset: CGFloat(direction * -25), angle: Double(direction * -60), opacity: 0, scale: 0.9),
                identity: PanRotateModifier(offset: 0, angle: 0, opacity: 1, scale: 1.0)
            )
        )
    }

    static func dynamicPanRotate(direction: Int) -> AnyTransition {
        return .asymmetric(
            insertion: .modifier(
                active: PanRotateModifier(offset: CGFloat(direction * 80), angle: Double(direction * 90), opacity: 0, scale: 0.75),
                identity: PanRotateModifier(offset: 0, angle: 0, opacity: 1, scale: 1.0)
            ),
            removal: .modifier(
                active: PanRotateModifier(offset: CGFloat(direction * -80), angle: Double(direction * -90), opacity: 0, scale: 0.75),
                identity: PanRotateModifier(offset: 0, angle: 0, opacity: 1, scale: 1.0)
            )
        )
    }
}
