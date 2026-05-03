import SwiftUI
import Combine
import AppKit
import CoreLocation

struct WidgetFactoryView: View {
    let widgetType: NotchWidgetType
    
    @ObservedObject var nowPlaying: NowPlayingManager
    let expandedWidth: CGFloat
    var isCompact: Bool
    @Binding var skipDirection: Int
    @Binding var glowOpacity: Double
    let onSwipe: (Bool) -> Void
    
    @AppStorage("themeBackgroundType") var themeBackgroundType: String = "color"
    @AppStorage("themeGlassyWidgets") var themeGlassyWidgets: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {
            if widgetType == .player {
                PlayerTabView(
                    nowPlaying: nowPlaying,
                    expandedWidth: expandedWidth,
                    isCompact: isCompact,
                    skipDirection: $skipDirection,
                    glowOpacity: $glowOpacity,
                    onSwipe: onSwipe
                )
            } else {
                Group {
                    switch widgetType {
                    case .player: EmptyView() // Handled above
                    case .spotifyQueue: SpotifyQueueWidget(nowPlaying: nowPlaying)
                    case .spotifyPlaylists: PlaylistTabView(nowPlaying: nowPlaying)
                    case .youtubeQueue: YouTubeQueueWidget(nowPlaying: nowPlaying)
                    case .youtubePlaylists: YouTubePlaylistsWidget(nowPlaying: nowPlaying)
                    case .calendar: CalendarWidget()
                    case .pomodoro: PomodoroTimerWidget(isCompact: isCompact)
                    case .clipboard: ClipboardHistoryWidget()
                    case .kaomoji: KaomojiBoardWidget()
                    case .weather: WeatherWidget()
                    }
                }
                .frame(maxHeight: .infinity)
                .background(
                    Group {
                        if themeBackgroundType == "image" && themeGlassyWidgets {
                            if #available(macOS 26.0, *) {
                                Color.clear.glassEffect(in: .rect(cornerRadius: 16))
                            } else {
                                ZStack {
                                    VisualEffectView(material: .popover, blendingMode: .withinWindow, alpha: 0.5)
                                    LinearGradient(colors: [Color.white.opacity(0.15), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                                }
                            }
                        } else {
                            Color.white.opacity(0.03)
                        }
                    }
                )
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
            }
        }
    }
}

struct CalendarWidget: View {
    @ObservedObject var googleManager = GoogleCalendarManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !googleManager.isAuthenticated {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 24))
                        .foregroundColor(.orange)
                    Text("Google Login Required")
                        .font(.system(size: 13, weight: .bold))
                    Text("Please sign in to Google in the Plugin Store.")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if googleManager.isFetching && googleManager.upcomingEvents.isEmpty {
                VStack {
                    Spacer()
                    ProgressView().controlSize(.small)
                    Text("Syncing Google Calendar...")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .padding(.top, 4)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else if googleManager.upcomingEvents.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 24))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("All clear for today!")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(googleManager.upcomingEvents) { event in
                            HStack(spacing: 10) {
                                // Calendar Color Strip
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(colorFromHex(event.calendarColor))
                                    .frame(width: 3, height: 24)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(event.summary)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    
                                    Text(formatGoogleEventTime(event))
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            googleManager.fetchTodaysEvents()
        }
    }
    
    private func colorFromHex(_ hex: String?) -> Color {
        guard let hex = hex else { return .accentColor }
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanHex.hasPrefix("#") { cleanHex.removeFirst() }
        
        var rgb: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&rgb)
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        return Color(red: r, green: g, blue: b)
    }
    
    private func formatGoogleEventTime(_ event: GoogleCalendarEvent) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        if let startStr = event.start.dateTime, let endStr = event.end.dateTime {
            let iso = ISO8601DateFormatter()
            if let start = iso.date(from: startStr), let end = iso.date(from: endStr) {
                return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
            }
        }
        
        return "All Day"
    }
}

enum PomodoroMode: String {
    case focus
    case shortBreak
    case longBreak

    var title: String {
        switch self {
        case .focus: return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak: return "Long Break"
        }
    }

    var subtitle: String {
        switch self {
        case .focus: return "Study session"
        case .shortBreak: return "Quick reset"
        case .longBreak: return "Long reset"
        }
    }

    var color: Color {
        switch self {
        case .focus: return .red
        case .shortBreak: return .green
        case .longBreak: return .blue
        }
    }
}

final class PomodoroTimerManager: ObservableObject {
    static let shared = PomodoroTimerManager()

    @Published private(set) var mode: PomodoroMode
    @Published private(set) var remainingSeconds: Int
    @Published private(set) var totalSeconds: Int
    @Published private(set) var isRunning = false
    @Published private(set) var completedFocusSessions: Int
    @Published private(set) var longBreakEvery: Int

    private var timer: Timer?
    private let defaults = UserDefaults.standard

    private enum Key {
        static let mode = "pomodoro_mode"
        static let remainingSeconds = "pomodoro_remaining_seconds"
        static let completedFocusSessions = "pomodoro_completed_focus_sessions"
        static let focusMinutes = "pomodoro_focus_minutes"
        static let shortBreakMinutes = "pomodoro_short_break_minutes"
        static let longBreakMinutes = "pomodoro_long_break_minutes"
        static let longBreakEvery = "pomodoro_long_break_every"
    }

    private init() {
        let storedMode = defaults.string(forKey: Key.mode).flatMap(PomodoroMode.init(rawValue:)) ?? .focus
        let storedCompleted = defaults.integer(forKey: Key.completedFocusSessions)
        let total = Self.duration(for: storedMode, defaults: defaults)
        let storedRemaining = defaults.object(forKey: Key.remainingSeconds) as? Int
        let storedLongBreakEvery = Self.storedLongBreakEvery(defaults: defaults)

        mode = storedMode
        completedFocusSessions = storedCompleted
        totalSeconds = total
        remainingSeconds = min(max(storedRemaining ?? total, 0), total)
        longBreakEvery = storedLongBreakEvery
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return 1.0 - (Double(remainingSeconds) / Double(totalSeconds))
    }

    var timeText: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var roundText: String {
        let round = (completedFocusSessions % longBreakEvery) + 1
        return "Round \(round)/\(longBreakEvery)"
    }

    func startPause() {
        isRunning ? pause() : start()
    }

    func start() {
        syncSettings()
        if remainingSeconds <= 0 {
            reset()
        }
        isRunning = true
        scheduleTimer()
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        persist()
    }

    func reset() {
        pause()
        totalSeconds = Self.duration(for: mode, defaults: defaults)
        remainingSeconds = totalSeconds
        persist()
    }

    func skip() {
        advanceSession(keepRunning: isRunning)
    }

    func syncSettings() {
        let newTotal = Self.duration(for: mode, defaults: defaults)
        let newLongBreakEvery = Self.storedLongBreakEvery(defaults: defaults)
        guard newTotal != totalSeconds || newLongBreakEvery != longBreakEvery else { return }

        if newLongBreakEvery != longBreakEvery {
            longBreakEvery = newLongBreakEvery
        }

        if newTotal != totalSeconds {
            totalSeconds = newTotal
            if isRunning {
                remainingSeconds = min(remainingSeconds, newTotal)
            } else {
                remainingSeconds = newTotal
            }
        }

        persist()
    }

    private func scheduleTimer() {
        timer?.invalidate()
        let newTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer = newTimer
        RunLoop.main.add(newTimer, forMode: .common)
    }

    private func tick() {
        guard isRunning else { return }

        if remainingSeconds > 0 {
            remainingSeconds -= 1
        }

        if remainingSeconds <= 0 {
            advanceSession(keepRunning: true)
        } else {
            persist()
        }
    }

    private func advanceSession(keepRunning: Bool) {
        if mode == .focus {
            completedFocusSessions += 1
            mode = completedFocusSessions % longBreakEvery == 0 ? .longBreak : .shortBreak
        } else {
            mode = .focus
        }

        totalSeconds = Self.duration(for: mode, defaults: defaults)
        remainingSeconds = totalSeconds
        isRunning = keepRunning
        persist()

        if keepRunning && timer == nil {
            scheduleTimer()
        }
    }

    private func persist() {
        defaults.set(mode.rawValue, forKey: Key.mode)
        defaults.set(remainingSeconds, forKey: Key.remainingSeconds)
        defaults.set(completedFocusSessions, forKey: Key.completedFocusSessions)
    }

    private static func duration(for mode: PomodoroMode, defaults: UserDefaults) -> Int {
        let minutes: Int
        switch mode {
        case .focus:
            minutes = storedMinutes(forKey: Key.focusMinutes, defaultValue: 25, defaults: defaults)
        case .shortBreak:
            minutes = storedMinutes(forKey: Key.shortBreakMinutes, defaultValue: 5, defaults: defaults)
        case .longBreak:
            minutes = storedMinutes(forKey: Key.longBreakMinutes, defaultValue: 15, defaults: defaults)
        }
        return minutes * 60
    }

    private static func storedMinutes(forKey key: String, defaultValue: Int, defaults: UserDefaults) -> Int {
        let stored = defaults.integer(forKey: key)
        return stored > 0 ? stored : defaultValue
    }

    private static func storedLongBreakEvery(defaults: UserDefaults) -> Int {
        let stored = defaults.integer(forKey: Key.longBreakEvery)
        return min(max(stored > 0 ? stored : 4, 2), 8)
    }
}

struct PomodoroTimerWidget: View {
    @StateObject private var timer = PomodoroTimerManager.shared
    let isCompact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(timer.mode.color)
                Text("Pomodoro")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                Text(timer.roundText)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
            }

            HStack(spacing: isCompact ? 10 : 12) {
                progressRing

                VStack(alignment: .leading, spacing: 3) {
                    Text(timer.mode.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(timer.mode.color)
                    Text(timer.timeText)
                        .font(.system(size: isCompact ? 26 : 30, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: timer.timeText)
                    Text(timer.isRunning ? "In progress" : timer.mode.subtitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                pomodoroButton(
                    systemName: timer.isRunning ? "pause.fill" : "play.fill",
                    label: timer.isRunning ? "Pause" : "Start",
                    isPrimary: true,
                    action: timer.startPause
                )
                pomodoroButton(systemName: "arrow.counterclockwise", label: "Reset", action: timer.reset)
                pomodoroButton(systemName: "forward.end.fill", label: "Skip", action: timer.skip)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            timer.syncSettings()
        }
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 6)
            Circle()
                .trim(from: 0, to: max(0.001, timer.progress))
                .stroke(timer.mode.color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(timer.progress * 100))%")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.75))
        }
        .frame(width: isCompact ? 54 : 58, height: isCompact ? 54 : 58)
    }

    private func pomodoroButton(systemName: String, label: String, isPrimary: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(isPrimary ? .black : .white.opacity(0.85))
                .frame(width: 32, height: 26)
                .background(isPrimary ? timer.mode.color : Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(label)
    }
}

enum ClipboardHistoryKind: String, Codable {
    case text
    case url
    case file
    case image
}

struct ClipboardHistoryItem: Codable, Identifiable, Equatable {
    let id: UUID
    let kind: ClipboardHistoryKind
    let text: String
    let filePaths: [String]
    let imageFileName: String?
    let imageWidth: Int?
    let imageHeight: Int?
    let imageByteCount: Int
    let payloadHash: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        kind: ClipboardHistoryKind,
        text: String = "",
        filePaths: [String] = [],
        imageFileName: String? = nil,
        imageWidth: Int? = nil,
        imageHeight: Int? = nil,
        imageByteCount: Int = 0,
        payloadHash: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.filePaths = filePaths
        self.imageFileName = imageFileName
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.imageByteCount = imageByteCount
        self.payloadHash = payloadHash ?? Self.makePayloadHash(
            kind: kind,
            text: text,
            filePaths: filePaths,
            imageFileName: imageFileName,
            imageByteCount: imageByteCount
        )
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case text
        case filePaths
        case imageFileName
        case imageWidth
        case imageHeight
        case imageByteCount
        case payloadHash
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedKind = try container.decodeIfPresent(ClipboardHistoryKind.self, forKey: .kind) ?? .text
        let decodedText = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        let decodedFilePaths = try container.decodeIfPresent([String].self, forKey: .filePaths) ?? []
        let decodedImageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
        let decodedImageByteCount = try container.decodeIfPresent(Int.self, forKey: .imageByteCount) ?? 0

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = decodedKind
        text = decodedText
        filePaths = decodedFilePaths
        imageFileName = decodedImageFileName
        imageWidth = try container.decodeIfPresent(Int.self, forKey: .imageWidth)
        imageHeight = try container.decodeIfPresent(Int.self, forKey: .imageHeight)
        imageByteCount = decodedImageByteCount
        payloadHash = try container.decodeIfPresent(String.self, forKey: .payloadHash) ?? Self.makePayloadHash(
            kind: decodedKind,
            text: decodedText,
            filePaths: decodedFilePaths,
            imageFileName: decodedImageFileName,
            imageByteCount: decodedImageByteCount
        )
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    var displayTitle: String {
        switch kind {
        case .text, .url:
            let firstLine = text
                .components(separatedBy: .newlines)
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return firstLine.isEmpty ? "Copied Text" : firstLine
        case .file:
            if filePaths.count == 1, let path = filePaths.first {
                return URL(fileURLWithPath: path).lastPathComponent
            }
            return "\(filePaths.count) Files"
        case .image:
            if let imageWidth, let imageHeight {
                return "Image \(imageWidth)x\(imageHeight)"
            }
            return "Copied Image"
        }
    }

    var preview: String {
        switch kind {
        case .text, .url:
            return text
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\t", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        case .file:
            let names = filePaths.prefix(3).map { URL(fileURLWithPath: $0).lastPathComponent }
            let suffix = filePaths.count > 3 ? " +" + String(filePaths.count - 3) : ""
            return names.joined(separator: ", ") + suffix
        case .image:
            return formattedByteCount
        }
    }

    var formattedByteCount: String {
        guard imageByteCount > 0 else { return "Image" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(imageByteCount))
    }

    private static func makePayloadHash(
        kind: ClipboardHistoryKind,
        text: String,
        filePaths: [String],
        imageFileName: String?,
        imageByteCount: Int
    ) -> String {
        switch kind {
        case .text, .url:
            return "\(kind.rawValue):\(text)"
        case .file:
            return "\(kind.rawValue):\(filePaths.joined(separator: "\n"))"
        case .image:
            return "\(kind.rawValue):\(imageFileName ?? ""):\(imageByteCount)"
        }
    }
}

final class ClipboardHistoryManager: ObservableObject {
    static let shared = ClipboardHistoryManager()

    @Published private(set) var items: [ClipboardHistoryItem] = []

    private let pasteboard = NSPasteboard.general
    private let defaults = UserDefaults.standard
    private var lastChangeCount: Int
    private var timer: Timer?

    private enum Key {
        static let storedItems = "clipboard_history_items"
        static let historyLimit = "clipboard_history_limit"
        static let pluginEnabled = "plugin_clipboard_history_enabled"
        static let trackFiles = "clipboard_history_track_files"
        static let trackImages = "clipboard_history_track_images"
    }

    private enum Constants {
        static let maxStoredImageBytes = 12 * 1024 * 1024
        static let fileNamesPasteboardType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
    }

    private init() {
        lastChangeCount = pasteboard.changeCount
        loadItems()
        schedulePolling()
    }

    var historyLimit: Int {
        let stored = defaults.integer(forKey: Key.historyLimit)
        return min(max(stored > 0 ? stored : 30, 5), 100)
    }

    var trackFiles: Bool {
        defaults.object(forKey: Key.trackFiles) as? Bool ?? true
    }

    var trackImages: Bool {
        defaults.object(forKey: Key.trackImages) as? Bool ?? true
    }

    func copyBack(_ item: ClipboardHistoryItem) {
        pasteboard.clearContents()

        switch item.kind {
        case .text:
            pasteboard.setString(item.text, forType: .string)
        case .url:
            if let url = URL(string: item.text) {
                pasteboard.writeObjects([url as NSURL])
            } else {
                pasteboard.setString(item.text, forType: .string)
            }
        case .file:
            let urls = item.filePaths.map { NSURL(fileURLWithPath: $0) }
            if urls.isEmpty {
                pasteboard.setString(item.text, forType: .string)
            } else {
                pasteboard.writeObjects(urls)
            }
        case .image:
            if let data = imageData(for: item), let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            }
        }

        lastChangeCount = pasteboard.changeCount
        moveExistingItemToTop(item)
    }

    func delete(_ item: ClipboardHistoryItem) {
        if let removed = items.first(where: { $0.id == item.id }) {
            removeImageFile(for: removed)
        }
        items.removeAll { $0.id == item.id }
        persistItems()
    }

    func clearHistory() {
        items.forEach(removeImageFile)
        items.removeAll()
        persistItems()
    }

    func syncSettings() {
        let itemCount = items.count
        pruneToLimit()
        if items.count != itemCount {
            persistItems()
        }
    }

    func image(for item: ClipboardHistoryItem) -> NSImage? {
        guard let data = imageData(for: item) else { return nil }
        return NSImage(data: data)
    }

    private func schedulePolling() {
        timer?.invalidate()
        let newTimer = Timer(timeInterval: 0.8, repeats: true) { [weak self] _ in
            self?.pollPasteboard()
        }
        timer = newTimer
        RunLoop.main.add(newTimer, forMode: .common)
    }

    private func pollPasteboard() {
        guard defaults.bool(forKey: Key.pluginEnabled) else {
            lastChangeCount = pasteboard.changeCount
            return
        }

        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount

        guard let copiedItem = readClipboardItem() else { return }
        record(copiedItem)
    }

    private func readClipboardItem() -> ClipboardHistoryItem? {
        if let fileItem = readClipboardFiles() {
            return fileItem
        }
        if let imageItem = readClipboardImage() {
            return imageItem
        }
        return readClipboardText()
    }

    private func readClipboardText() -> ClipboardHistoryItem? {
        if pasteboardContainsFileReferences() {
            return nil
        }

        let rawText = pasteboard.string(forType: .string)
            ?? pasteboard.string(forType: .URL)
        let text = rawText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return nil }

        let isURL = URL(string: text)?.scheme != nil
        let kind: ClipboardHistoryKind = isURL ? .url : .text
        return ClipboardHistoryItem(
            kind: kind,
            text: text,
            payloadHash: "\(kind.rawValue):\(Self.hashString(text))"
        )
    }

    private func readClipboardFiles() -> ClipboardHistoryItem? {
        guard trackFiles else { return nil }

        var filePaths: [String] = []
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [NSURL] {
            filePaths.append(contentsOf: urls.map { ($0 as URL).path })
        }

        if let paths = pasteboard.propertyList(forType: Constants.fileNamesPasteboardType) as? [String] {
            filePaths.append(contentsOf: paths)
        }

        let uniquePaths = NSOrderedSet(array: filePaths.filter { !$0.isEmpty }).array as? [String] ?? []
        guard !uniquePaths.isEmpty else { return nil }

        return ClipboardHistoryItem(
            kind: .file,
            text: uniquePaths.joined(separator: "\n"),
            filePaths: uniquePaths,
            payloadHash: "file:\(Self.hashString(uniquePaths.joined(separator: "\n")))"
        )
    }

    private func readClipboardImage() -> ClipboardHistoryItem? {
        guard trackImages else { return nil }

        if let pngData = pasteboard.data(forType: .png),
           let item = makeImageItem(from: pngData) {
            return item
        }

        if let tiffData = pasteboard.data(forType: .tiff),
           let image = NSImage(data: tiffData),
           let pngData = pngData(from: image),
           let item = makeImageItem(from: pngData, fallbackImage: image) {
            return item
        }

        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let image = images.first,
           let pngData = pngData(from: image),
           let item = makeImageItem(from: pngData, fallbackImage: image) {
            return item
        }

        return nil
    }

    private func makeImageItem(from data: Data, fallbackImage: NSImage? = nil) -> ClipboardHistoryItem? {
        guard data.count <= Constants.maxStoredImageBytes else { return nil }

        let id = UUID()
        let image = fallbackImage ?? NSImage(data: data)
        guard let fileName = storeImageData(data, id: id) else { return nil }

        return ClipboardHistoryItem(
            id: id,
            kind: .image,
            imageFileName: fileName,
            imageWidth: image.map { Int($0.size.width.rounded()) },
            imageHeight: image.map { Int($0.size.height.rounded()) },
            imageByteCount: data.count,
            payloadHash: "image:\(Self.hashData(data))"
        )
    }

    private func record(_ item: ClipboardHistoryItem) {
        let duplicates = items.filter { $0.payloadHash == item.payloadHash }
        duplicates.forEach(removeImageFile)
        items.removeAll { $0.payloadHash == item.payloadHash }
        items.insert(item, at: 0)
        pruneToLimit()
        persistItems()
    }

    private func moveExistingItemToTop(_ item: ClipboardHistoryItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let existingItem = items.remove(at: index)
        items.insert(existingItem, at: 0)
        persistItems()
    }

    private func pruneToLimit() {
        if items.count > historyLimit {
            items.dropFirst(historyLimit).forEach(removeImageFile)
            items = Array(items.prefix(historyLimit))
        }
    }

    private func loadItems() {
        guard let data = defaults.data(forKey: Key.storedItems),
              let decoded = try? JSONDecoder().decode([ClipboardHistoryItem].self, from: data) else {
            items = []
            return
        }
        items = Array(decoded.prefix(historyLimit))
    }

    private func persistItems() {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: Key.storedItems)
        }
    }

    private func pasteboardContainsFileReferences() -> Bool {
        pasteboard.availableType(from: [.fileURL, Constants.fileNamesPasteboardType]) != nil
    }

    private func storeImageData(_ data: Data, id: UUID) -> String? {
        guard let directory = imageCacheDirectory() else { return nil }
        let fileName = "\(id.uuidString).png"
        do {
            try data.write(to: directory.appendingPathComponent(fileName), options: .atomic)
            return fileName
        } catch {
            return nil
        }
    }

    private func imageData(for item: ClipboardHistoryItem) -> Data? {
        guard let fileName = item.imageFileName,
              let directory = imageCacheDirectory() else {
            return nil
        }
        return try? Data(contentsOf: directory.appendingPathComponent(fileName))
    }

    private func removeImageFile(for item: ClipboardHistoryItem) {
        guard let fileName = item.imageFileName,
              let directory = imageCacheDirectory() else {
            return
        }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(fileName))
    }

    private func imageCacheDirectory() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = appSupport
            .appendingPathComponent("WaveNotch", isDirectory: true)
            .appendingPathComponent("ClipboardHistoryImages", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        } catch {
            return nil
        }
    }

    private func pngData(from image: NSImage) -> Data? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }

    private static func hashString(_ value: String) -> String {
        hashData(Data(value.utf8))
    }

    private static func hashData(_ data: Data) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in data {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}

struct ClipboardHistoryWidget: View {
    @StateObject private var clipboard = ClipboardHistoryManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.purple)
                Text("Clipboard")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                Text("\(clipboard.items.count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .monospacedDigit()
                Spacer()
                Button {
                    clipboard.clearHistory()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Clear Clipboard History")
                .disabled(clipboard.items.isEmpty)
            }

            if clipboard.items.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(clipboard.items) { item in
                            ClipboardHistoryRow(item: item)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            clipboard.syncSettings()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.purple.opacity(0.8))
            Text("Copy text, images, or files to save them here.")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct ClipboardHistoryRow: View {
    let item: ClipboardHistoryItem
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Button {
                ClipboardHistoryManager.shared.copyBack(item)
            } label: {
                HStack(spacing: 8) {
                    leadingVisual

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.displayTitle)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(item.preview)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.48))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    Text(relativeTime)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.35))
                        .monospacedDigit()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(isHovering ? Color.white.opacity(0.10) : Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Copy Back")
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }

            Button {
                ClipboardHistoryManager.shared.delete(item)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.45))
                    .frame(width: 18, height: 18)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Remove")
        }
    }

    @ViewBuilder
    private var leadingVisual: some View {
        switch item.kind {
        case .image:
            if let image = ClipboardHistoryManager.shared.image(for: item) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                symbolVisual
            }
        case .file:
            if let path = item.filePaths.first {
                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .frame(width: 30, height: 30)
            } else {
                symbolVisual
            }
        case .text, .url:
            symbolVisual
        }
    }

    private var symbolVisual: some View {
        Image(systemName: symbolName)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.purple.opacity(0.9))
            .frame(width: 30, height: 30)
            .background(Color.purple.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var symbolName: String {
        switch item.kind {
        case .url:
            return "link"
        case .file:
            return "doc"
        case .image:
            return "photo"
        case .text:
            return "doc.text"
        }
    }

    private var relativeTime: String {
        let seconds = max(0, Int(Date().timeIntervalSince(item.createdAt)))
        if seconds < 60 { return "now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        return "\(hours / 24)d"
    }
}

enum KaomojiBoardCategory: String, CaseIterable, Identifiable {
    case faces
    case mood
    case action
    case symbols
    case emoji

    var id: String { rawValue }

    var title: String {
        switch self {
        case .faces: return "Faces"
        case .mood: return "Mood"
        case .action: return "Action"
        case .symbols: return "Symbols"
        case .emoji: return "Emoji"
        }
    }
}

struct KaomojiBoardEntry: Identifiable, Hashable {
    let category: KaomojiBoardCategory
    let text: String
    let label: String

    var id: String { "\(category.rawValue)|\(text)" }
}

final class KaomojiBoardManager: ObservableObject {
    static let shared = KaomojiBoardManager()

    @Published private(set) var recentItems: [String] = []

    private let defaults = UserDefaults.standard

    private enum Key {
        static let recentItems = "kaomoji_board_recent_items"
        static let recentLimit = "kaomoji_board_recent_limit"
    }

    private init() {
        loadRecent()
    }

    var recentLimit: Int {
        let stored = defaults.object(forKey: Key.recentLimit) as? Int ?? 12
        return min(max(stored, 0), 24)
    }

    var hasRecentItems: Bool {
        !recentItems.isEmpty && recentLimit > 0
    }

    func entries(for category: KaomojiBoardCategory) -> [KaomojiBoardEntry] {
        Self.entries.filter { $0.category == category }
    }

    func copy(_ entry: KaomojiBoardEntry) {
        copyText(entry.text)
    }

    func copyRecent(_ text: String) {
        copyText(text)
    }

    func clearRecent() {
        recentItems.removeAll()
        persistRecent()
    }

    func syncSettings() {
        let previousItems = recentItems
        pruneRecent()
        if previousItems != recentItems {
            persistRecent()
        }
    }

    private func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        remember(text)
    }

    private func remember(_ text: String) {
        guard recentLimit > 0 else { return }
        recentItems.removeAll { $0 == text }
        recentItems.insert(text, at: 0)
        pruneRecent()
        persistRecent()
    }

    private func pruneRecent() {
        if recentItems.count > recentLimit {
            recentItems = Array(recentItems.prefix(recentLimit))
        }
    }

    private func loadRecent() {
        let stored = defaults.stringArray(forKey: Key.recentItems) ?? []
        recentItems = Array(stored.prefix(recentLimit))
    }

    private func persistRecent() {
        defaults.set(recentItems, forKey: Key.recentItems)
    }

    private static let entries: [KaomojiBoardEntry] = [
        KaomojiBoardEntry(category: .faces, text: #"(ง'̀-'́)ง"#, label: "fight"),
        KaomojiBoardEntry(category: .faces, text: #"¯\_(ツ)_/¯"#, label: "shrug"),
        KaomojiBoardEntry(category: .faces, text: #"ಠ_ಠ"#, label: "stare"),
        KaomojiBoardEntry(category: .faces, text: #"( ͡° ͜ʖ ͡°)"#, label: "lenny"),
        KaomojiBoardEntry(category: .faces, text: #"(⌐■_■)"#, label: "cool"),
        KaomojiBoardEntry(category: .faces, text: #"(¬_¬)"#, label: "side eye"),
        KaomojiBoardEntry(category: .faces, text: #"(•_•)"#, label: "deadpan"),
        KaomojiBoardEntry(category: .faces, text: #"(ᵔᴥᵔ)"#, label: "soft"),
        KaomojiBoardEntry(category: .faces, text: #"ʕ•ᴥ•ʔ"#, label: "cute"),
        KaomojiBoardEntry(category: .faces, text: #"(｡◕‿◕｡)"#, label: "smile"),
        KaomojiBoardEntry(category: .faces, text: #"(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧"#, label: "sparkle"),
        KaomojiBoardEntry(category: .faces, text: #"ᕕ( ᐛ )ᕗ"#, label: "march"),

        KaomojiBoardEntry(category: .mood, text: #"(｡♥‿♥｡)"#, label: "love"),
        KaomojiBoardEntry(category: .mood, text: #"(ಥ﹏ಥ)"#, label: "cry"),
        KaomojiBoardEntry(category: .mood, text: #"(╥_╥)"#, label: "sad"),
        KaomojiBoardEntry(category: .mood, text: #"(ง •̀_•́)ง"#, label: "ready"),
        KaomojiBoardEntry(category: .mood, text: #"(ﾉಥ益ಥ）ﾉ"#, label: "rage"),
        KaomojiBoardEntry(category: .mood, text: #"(ᗒᗣᗕ)՞"#, label: "panic"),
        KaomojiBoardEntry(category: .mood, text: #"(￣▽￣)"#, label: "relaxed"),
        KaomojiBoardEntry(category: .mood, text: #"٩(◕‿◕｡)۶"#, label: "happy"),
        KaomojiBoardEntry(category: .mood, text: #"(｡•́︿•̀｡)"#, label: "down"),
        KaomojiBoardEntry(category: .mood, text: #"(≧◡≦)"#, label: "joy"),
        KaomojiBoardEntry(category: .mood, text: #"(*≧ω≦*)"#, label: "excited"),
        KaomojiBoardEntry(category: .mood, text: #"(；￣Д￣)"#, label: "worried"),

        KaomojiBoardEntry(category: .action, text: #"(づ｡◕‿‿◕｡)づ"#, label: "hug"),
        KaomojiBoardEntry(category: .action, text: #"(╯°□°）╯︵ ┻━┻"#, label: "flip"),
        KaomojiBoardEntry(category: .action, text: #"┬─┬ ノ( ゜-゜ノ)"#, label: "fix"),
        KaomojiBoardEntry(category: .action, text: #"(☞ﾟヮﾟ)☞"#, label: "point"),
        KaomojiBoardEntry(category: .action, text: #"☜(ﾟヮﾟ☜)"#, label: "point"),
        KaomojiBoardEntry(category: .action, text: #"ᕙ(⇀‸↼‶)ᕗ"#, label: "flex"),
        KaomojiBoardEntry(category: .action, text: #"(ง°ل͜°)ง"#, label: "go"),
        KaomojiBoardEntry(category: .action, text: #"\(^_^)/"#, label: "cheer"),
        KaomojiBoardEntry(category: .action, text: #"ヽ(•‿•)ノ"#, label: "wave"),
        KaomojiBoardEntry(category: .action, text: #"(シ_ _)シ"#, label: "bow"),
        KaomojiBoardEntry(category: .action, text: #"(っ˘ڡ˘ς)"#, label: "eat"),
        KaomojiBoardEntry(category: .action, text: #"ε=ε=ε=┌(;*´Д`)ﾉ"#, label: "run"),

        KaomojiBoardEntry(category: .symbols, text: #"★"#, label: "star"),
        KaomojiBoardEntry(category: .symbols, text: #"☆"#, label: "star"),
        KaomojiBoardEntry(category: .symbols, text: #"♡"#, label: "heart"),
        KaomojiBoardEntry(category: .symbols, text: #"♥"#, label: "heart"),
        KaomojiBoardEntry(category: .symbols, text: #"✓"#, label: "check"),
        KaomojiBoardEntry(category: .symbols, text: #"✕"#, label: "x"),
        KaomojiBoardEntry(category: .symbols, text: #"→"#, label: "arrow"),
        KaomojiBoardEntry(category: .symbols, text: #"←"#, label: "arrow"),
        KaomojiBoardEntry(category: .symbols, text: #"↑"#, label: "arrow"),
        KaomojiBoardEntry(category: .symbols, text: #"↓"#, label: "arrow"),
        KaomojiBoardEntry(category: .symbols, text: #"∞"#, label: "infinity"),
        KaomojiBoardEntry(category: .symbols, text: #"…"#, label: "ellipsis"),
        KaomojiBoardEntry(category: .symbols, text: #"•"#, label: "bullet"),
        KaomojiBoardEntry(category: .symbols, text: #"※"#, label: "note"),
        KaomojiBoardEntry(category: .symbols, text: #"♪"#, label: "music"),
        KaomojiBoardEntry(category: .symbols, text: #"♫"#, label: "music"),

        KaomojiBoardEntry(category: .emoji, text: #"😀"#, label: "grin"),
        KaomojiBoardEntry(category: .emoji, text: #"😂"#, label: "laugh"),
        KaomojiBoardEntry(category: .emoji, text: #"😭"#, label: "cry"),
        KaomojiBoardEntry(category: .emoji, text: #"🥲"#, label: "tear"),
        KaomojiBoardEntry(category: .emoji, text: #"😍"#, label: "love"),
        KaomojiBoardEntry(category: .emoji, text: #"😎"#, label: "cool"),
        KaomojiBoardEntry(category: .emoji, text: #"🤔"#, label: "think"),
        KaomojiBoardEntry(category: .emoji, text: #"👀"#, label: "eyes"),
        KaomojiBoardEntry(category: .emoji, text: #"🙏"#, label: "pray"),
        KaomojiBoardEntry(category: .emoji, text: #"💀"#, label: "dead"),
        KaomojiBoardEntry(category: .emoji, text: #"🔥"#, label: "fire"),
        KaomojiBoardEntry(category: .emoji, text: #"✨"#, label: "sparkles"),
        KaomojiBoardEntry(category: .emoji, text: #"✅"#, label: "done"),
        KaomojiBoardEntry(category: .emoji, text: #"❌"#, label: "no"),
        KaomojiBoardEntry(category: .emoji, text: #"🎯"#, label: "target"),
        KaomojiBoardEntry(category: .emoji, text: #"🚀"#, label: "ship")
    ]
}

struct KaomojiBoardWidget: View {
    @StateObject private var board = KaomojiBoardManager.shared
    @State private var selectedCategory: KaomojiBoardCategory = .faces
    @State private var copiedText: String?
    @State private var copiedResetTask: Task<Void, Never>?

    private let columns = [
        GridItem(.flexible(minimum: 0), spacing: 8),
        GridItem(.flexible(minimum: 0), spacing: 8),
        GridItem(.flexible(minimum: 0), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "face.smiling")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.pink)
                Text("Kaomoji")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                if copiedText != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            categoryStrip

            if board.hasRecentItems {
                recentStrip
            }

            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(board.entries(for: selectedCategory)) { entry in
                        KaomojiTokenButton(
                            text: entry.text,
                            label: entry.label,
                            isCopied: copiedText == entry.text
                        ) {
                            copy(entry)
                        }
                    }
                }
                .padding(.bottom, 2)
            }
            .clipped()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            board.syncSettings()
        }
        .onDisappear {
            copiedResetTask?.cancel()
        }
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(KaomojiBoardCategory.allCases) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category.title)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(selectedCategory == category ? .white : .white.opacity(0.62))
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .background(selectedCategory == category ? Color.pink.opacity(0.72) : Color.white.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(height: 28)
        .clipped()
    }

    private var recentStrip: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.45))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(board.recentItems, id: \.self) { text in
                        Button {
                            board.copyRecent(text)
                            markCopied(text)
                        } label: {
                            Text(text)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                                .allowsTightening(true)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .frame(height: 28)
                                .frame(minWidth: 42)
                                .background(copiedText == text ? Color.green.opacity(0.28) : Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .clipped()
                        }
                        .buttonStyle(.plain)
                        .help(text)
                    }
                }
            }
        }
    }

    private func copy(_ entry: KaomojiBoardEntry) {
        board.copy(entry)
        markCopied(entry.text)
    }

    private func markCopied(_ text: String) {
        copiedText = text
        copiedResetTask?.cancel()
        copiedResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            if copiedText == text {
                copiedText = nil
            }
        }
    }
}

struct KaomojiTokenButton: View {
    let text: String
    let label: String
    let isCopied: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(text)
                    .font(.system(size: text.count <= 2 ? 21 : 15, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.38)
                    .allowsTightening(true)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .clipped()
                Text(label)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.white.opacity(0.38))
                    .lineLimit(1)
                    .clipped()
            }
            .padding(.horizontal, 7)
            .frame(height: 48)
            .frame(maxWidth: .infinity)
            .background(isCopied ? Color.green.opacity(0.26) : Color.white.opacity(0.07))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isCopied ? Color.green.opacity(0.4) : Color.white.opacity(0.05), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .clipped()
        }
        .buttonStyle(.plain)
        .help(text)
    }
}

struct WeatherSnapshot: Equatable {
    let locationName: String
    let country: String?
    let temperature: Double
    let apparentTemperature: Double
    let humidity: Int
    let windSpeed: Double
    let precipitation: Double
    let weatherCode: Int
    let high: Double?
    let low: Double?
    let unit: String
    let fetchedAt: Date

    var temperatureNumberText: String {
        "\(Int(temperature.rounded()))"
    }

    var unitLetter: String {
        unit == "fahrenheit" ? "F" : "C"
    }

    var temperatureText: String {
        "\(Int(temperature.rounded()))\(unitSymbol)"
    }

    var apparentText: String {
        "\(Int(apparentTemperature.rounded()))\(unitSymbol)"
    }

    var highLowText: String {
        guard let high, let low else { return "" }
        return "H \(Int(high.rounded()))\(unitSymbol)  L \(Int(low.rounded()))\(unitSymbol)"
    }

    var unitSymbol: String {
        "°\(unitLetter)"
    }

    var windText: String {
        let suffix = unit == "fahrenheit" ? "mph" : "km/h"
        return "\(Int(windSpeed.rounded())) \(suffix)"
    }
}

struct WeatherResolvedLocation {
    let displayName: String
    let latitude: Double
    let longitude: Double
    let country: String?
}

struct WeatherLocationResult: Decodable {
    let name: String
    let latitude: Double
    let longitude: Double
    let country: String?
    let admin1: String?

    var displayName: String {
        if let admin1, !admin1.isEmpty {
            return "\(name), \(admin1)"
        }
        return name
    }

    var resolvedLocation: WeatherResolvedLocation {
        WeatherResolvedLocation(
            displayName: displayName,
            latitude: latitude,
            longitude: longitude,
            country: country
        )
    }
}

private struct WeatherGeocodingResponse: Decodable {
    let results: [WeatherLocationResult]?
}

private struct OpenMeteoForecastResponse: Decodable {
    let current: OpenMeteoCurrent
    let daily: OpenMeteoDaily?
}

private struct OpenMeteoCurrent: Decodable {
    let temperature: Double
    let apparentTemperature: Double
    let humidity: Int
    let precipitation: Double
    let weatherCode: Int
    let windSpeed: Double

    enum CodingKeys: String, CodingKey {
        case temperature = "temperature_2m"
        case apparentTemperature = "apparent_temperature"
        case humidity = "relative_humidity_2m"
        case precipitation
        case weatherCode = "weather_code"
        case windSpeed = "wind_speed_10m"
    }
}

private struct OpenMeteoDaily: Decodable {
    let weatherCode: [Int]?
    let temperatureMax: [Double]?
    let temperatureMin: [Double]?

    enum CodingKeys: String, CodingKey {
        case weatherCode = "weather_code"
        case temperatureMax = "temperature_2m_max"
        case temperatureMin = "temperature_2m_min"
    }
}

final class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = WeatherManager()

    @Published private(set) var snapshot: WeatherSnapshot?
    @Published private(set) var isFetching = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var locationStatusText = "Current location"

    private let defaults = UserDefaults.standard
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var refreshTimer: Timer?
    private var lastRequestSignature = ""
    private var lastFetchDate: Date?
    private var lastFailureDate: Date?
    private var lastFailureSignature = ""
    private var pendingCurrentLocationUnit: String?
    private var pendingCurrentLocationForce = false
    private let successRefreshInterval: TimeInterval = 1800
    private let failureRetryInterval: TimeInterval = 300

    private enum Key {
        static let useCurrentLocation = "weather_use_current_location"
        static let locationQuery = "weather_location_query"
        static let temperatureUnit = "weather_temperature_unit"
        static let currentLatitude = "weather_current_latitude"
        static let currentLongitude = "weather_current_longitude"
        static let currentLocationName = "weather_current_location_name"
        static let currentLocationCountry = "weather_current_location_country"
    }

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.fetchWeather()
        }
        fetchWeather()
    }

    var useCurrentLocation: Bool {
        defaults.object(forKey: Key.useCurrentLocation) as? Bool ?? true
    }

    var configuredLocation: String {
        let stored = defaults.string(forKey: Key.locationQuery)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return stored.isEmpty ? "New York" : stored
    }

    var configuredUnit: String {
        let stored = defaults.string(forKey: Key.temperatureUnit) ?? "fahrenheit"
        return stored == "celsius" ? "celsius" : "fahrenheit"
    }

    func fetchWeather(force: Bool = false) {
        if isFetching && !force {
            return
        }

        let unit = configuredUnit

        if useCurrentLocation {
            fetchCurrentLocationWeather(unit: unit, force: force)
        } else {
            fetchManualLocationWeather(unit: unit, force: force)
        }
    }

    private func fetchManualLocationWeather(unit: String, force: Bool, fallbackStatus: String? = nil) {
        let locationQuery = configuredLocation
        let signature = "manual:\(locationQuery)|\(unit)"

        if !force,
           signature == lastRequestSignature,
           let lastFetchDate,
           Date().timeIntervalSince(lastFetchDate) < successRefreshInterval,
           snapshot != nil {
            return
        }

        if shouldSkipFailedFetch(signature: signature, force: force) {
            return
        }

        lastRequestSignature = signature
        DispatchQueue.main.async {
            self.isFetching = true
            self.errorMessage = nil
            self.locationStatusText = fallbackStatus ?? "Using manual location"
        }

        geocode(locationQuery) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let location):
                if fallbackStatus != nil,
                   self.lastRequestSignature.hasPrefix("current:"),
                   self.snapshot != nil {
                    return
                }
                self.fetchForecast(for: location, unit: unit)
            case .failure:
                DispatchQueue.main.async {
                    self.isFetching = false
                    self.recordWeatherFailure(signature: signature, message: "Location not found")
                    self.errorMessage = "Location not found"
                }
            }
        }
    }

    private func fetchCurrentLocationWeather(unit: String, force: Bool) {
        if !force, let cachedLocation = cachedCurrentLocation {
            let signature = "current:\(coordinateSignature(cachedLocation))|\(unit)"
            if signature == lastRequestSignature,
               let lastFetchDate,
               Date().timeIntervalSince(lastFetchDate) < successRefreshInterval,
               snapshot != nil {
                return
            }

            if shouldSkipFailedFetch(signature: signature, force: force) {
                return
            }

            lastRequestSignature = signature
            DispatchQueue.main.async {
                self.isFetching = true
                self.errorMessage = nil
                self.locationStatusText = "Using \(cachedLocation.displayName)"
            }
            fetchForecast(for: cachedLocation, unit: unit)
            return
        }

        let lookupSignature = "current:lookup|\(unit)"
        if shouldSkipCurrentStartupRetry(unit: unit, force: force) {
            return
        }
        if shouldSkipFailedFetch(signature: lookupSignature, force: force) {
            return
        }
        lastRequestSignature = lookupSignature
        requestCurrentLocation(unit: unit, force: force)

        if !force {
            fetchManualLocationWeather(
                unit: unit,
                force: true,
                fallbackStatus: "Using fallback while finding current location."
            )
        }
    }

    private func requestCurrentLocation(unit: String, force: Bool) {
        pendingCurrentLocationUnit = unit
        pendingCurrentLocationForce = force

        DispatchQueue.main.async {
            self.isFetching = true
            self.errorMessage = nil
            self.locationStatusText = "Finding current location..."
        }

        guard CLLocationManager.locationServicesEnabled() else {
            recordWeatherFailure(signature: lastRequestSignature, message: "Location Services are off")
            handleCurrentLocationUnavailable("Location Services are off", unit: unit, force: force)
            return
        }

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        case .denied, .restricted:
            recordWeatherFailure(signature: lastRequestSignature, message: "Location permission denied")
            handleCurrentLocationUnavailable("Location permission denied", unit: unit, force: force)
        @unknown default:
            recordWeatherFailure(signature: lastRequestSignature, message: "Location unavailable")
            handleCurrentLocationUnavailable("Location unavailable", unit: unit, force: force)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard let unit = pendingCurrentLocationUnit else { return }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            recordWeatherFailure(signature: lastRequestSignature, message: "Location permission denied")
            handleCurrentLocationUnavailable("Location permission denied", unit: unit, force: pendingCurrentLocationForce)
        case .notDetermined:
            break
        @unknown default:
            recordWeatherFailure(signature: lastRequestSignature, message: "Location unavailable")
            handleCurrentLocationUnavailable("Location unavailable", unit: unit, force: pendingCurrentLocationForce)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last,
              let unit = pendingCurrentLocationUnit else {
            handleCurrentLocationUnavailable("Location unavailable", unit: configuredUnit, force: true)
            return
        }

        pendingCurrentLocationUnit = nil
        pendingCurrentLocationForce = false

        reverseGeocode(location) { [weak self] resolvedLocation in
            guard let self else { return }
            self.cacheCurrentLocation(resolvedLocation)
            self.lastRequestSignature = "current:\(self.coordinateSignature(resolvedLocation))|\(unit)"
            self.locationStatusText = "Using \(resolvedLocation.displayName)"
            self.fetchForecast(for: resolvedLocation, unit: unit)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let unit = pendingCurrentLocationUnit ?? configuredUnit
        let force = pendingCurrentLocationForce
        pendingCurrentLocationUnit = nil
        pendingCurrentLocationForce = false
        recordWeatherFailure(signature: lastRequestSignature, message: "Current location unavailable")
        handleCurrentLocationUnavailable("Current location unavailable", unit: unit, force: force)
    }

    private func handleCurrentLocationUnavailable(_ message: String, unit: String, force: Bool) {
        pendingCurrentLocationUnit = nil
        pendingCurrentLocationForce = false

        if let cachedLocation = cachedCurrentLocation {
            lastRequestSignature = "current:\(coordinateSignature(cachedLocation))|\(unit)"
            DispatchQueue.main.async {
                self.locationStatusText = "\(message). Using last location."
            }
            fetchForecast(for: cachedLocation, unit: unit)
        } else {
            fetchManualLocationWeather(unit: unit, force: true, fallbackStatus: "\(message). Using fallback city.")
        }
    }

    private func geocode(_ query: String, completion: @escaping (Result<WeatherResolvedLocation, Error>) -> Void) {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "1"),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "format", value: "json")
        ]

        guard let url = components?.url else {
            completion(.failure(URLError(.badURL)))
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let data else {
                completion(.failure(URLError(.cannotParseResponse)))
                return
            }

            DispatchQueue.main.async {
                guard let response = try? JSONDecoder().decode(WeatherGeocodingResponse.self, from: data),
                      let location = response.results?.first else {
                    completion(.failure(URLError(.cannotParseResponse)))
                    return
                }

                completion(.success(location.resolvedLocation))
            }
        }.resume()
    }

    private func reverseGeocode(_ location: CLLocation, completion: @escaping (WeatherResolvedLocation) -> Void) {
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            DispatchQueue.main.async {
                let placemark = placemarks?.first
                let city = placemark?.locality?.trimmingCharacters(in: .whitespacesAndNewlines)
                let region = placemark?.administrativeArea?.trimmingCharacters(in: .whitespacesAndNewlines)
                let displayParts = [city, region]
                    .compactMap { value -> String? in
                        guard let value, !value.isEmpty else { return nil }
                        return value
                    }
                    .reduce(into: [String]()) { parts, value in
                        if !parts.contains(value) { parts.append(value) }
                    }

                let displayName = displayParts.isEmpty ? "Current Location" : displayParts.joined(separator: ", ")
                completion(
                    WeatherResolvedLocation(
                        displayName: displayName,
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude,
                        country: placemark?.country
                    )
                )
            }
        }
    }

    private var cachedCurrentLocation: WeatherResolvedLocation? {
        guard defaults.object(forKey: Key.currentLatitude) != nil,
              defaults.object(forKey: Key.currentLongitude) != nil else {
            return nil
        }

        let displayName = defaults.string(forKey: Key.currentLocationName)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return WeatherResolvedLocation(
            displayName: displayName?.isEmpty == false ? displayName! : "Current Location",
            latitude: defaults.double(forKey: Key.currentLatitude),
            longitude: defaults.double(forKey: Key.currentLongitude),
            country: defaults.string(forKey: Key.currentLocationCountry)
        )
    }

    private func cacheCurrentLocation(_ location: WeatherResolvedLocation) {
        defaults.set(location.latitude, forKey: Key.currentLatitude)
        defaults.set(location.longitude, forKey: Key.currentLongitude)
        defaults.set(location.displayName, forKey: Key.currentLocationName)
        defaults.set(location.country, forKey: Key.currentLocationCountry)
    }

    private func coordinateSignature(_ location: WeatherResolvedLocation) -> String {
        "\(String(format: "%.3f", location.latitude)),\(String(format: "%.3f", location.longitude))"
    }

    private func shouldSkipFailedFetch(signature: String, force: Bool) -> Bool {
        guard !force,
              signature == lastFailureSignature,
              let lastFailureDate,
              Date().timeIntervalSince(lastFailureDate) < failureRetryInterval else {
            return false
        }
        return true
    }

    private func shouldSkipCurrentStartupRetry(unit: String, force: Bool) -> Bool {
        guard !force,
              snapshot == nil,
              let lastFailureDate,
              Date().timeIntervalSince(lastFailureDate) < failureRetryInterval else {
            return false
        }

        return lastFailureSignature == "current:lookup|\(unit)" || lastFailureSignature.hasPrefix("manual:")
    }

    private func recordWeatherFailure(signature: String, message: String) {
        lastFailureSignature = signature
        lastFailureDate = Date()
        locationStatusText = message
    }

    private func fetchForecast(for location: WeatherResolvedLocation, unit: String) {
        let signature = lastRequestSignature
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(location.latitude)),
            URLQueryItem(name: "longitude", value: String(location.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "temperature_unit", value: unit),
            URLQueryItem(name: "wind_speed_unit", value: unit == "fahrenheit" ? "mph" : "kmh"),
            URLQueryItem(name: "precipitation_unit", value: unit == "fahrenheit" ? "inch" : "mm"),
            URLQueryItem(name: "forecast_days", value: "3"),
            URLQueryItem(name: "timezone", value: "auto")
        ]

        guard let url = components?.url else {
            DispatchQueue.main.async {
                self.isFetching = false
                self.recordWeatherFailure(signature: signature, message: "Weather request failed")
                self.errorMessage = "Weather request failed"
            }
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data, error == nil else {
                DispatchQueue.main.async {
                    self.isFetching = false
                    self.recordWeatherFailure(signature: signature, message: "Weather unavailable")
                    self.errorMessage = "Weather unavailable"
                }
                return
            }

            DispatchQueue.main.async {
                guard let response = try? JSONDecoder().decode(OpenMeteoForecastResponse.self, from: data) else {
                    self.isFetching = false
                    self.recordWeatherFailure(signature: signature, message: "Weather unavailable")
                    self.errorMessage = "Weather unavailable"
                    return
                }

                let snapshot = WeatherSnapshot(
                    locationName: location.displayName,
                    country: location.country,
                    temperature: response.current.temperature,
                    apparentTemperature: response.current.apparentTemperature,
                    humidity: response.current.humidity,
                    windSpeed: response.current.windSpeed,
                    precipitation: response.current.precipitation,
                    weatherCode: response.current.weatherCode,
                    high: response.daily?.temperatureMax?.first,
                    low: response.daily?.temperatureMin?.first,
                    unit: unit,
                    fetchedAt: Date()
                )

                self.snapshot = snapshot
                self.lastFetchDate = Date()
                self.lastFailureDate = nil
                self.lastFailureSignature = ""
                self.isFetching = false
                self.errorMessage = nil
            }
        }.resume()
    }
}

struct WeatherWidget: View {
    @StateObject private var weather = WeatherManager.shared

    var body: some View {
        Group {
            if let snapshot = weather.snapshot {
                weatherContent(snapshot)
            } else if weather.isFetching {
                loadingState
            } else {
                errorState
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            weather.fetchWeather()
        }
    }

    private func weatherContent(_ snapshot: WeatherSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(weatherColor(for: snapshot.weatherCode).opacity(0.16))
                    Image(systemName: weatherSymbol(for: snapshot.weatherCode))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(weatherColor(for: snapshot.weatherCode))
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.locationName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(conditionText(for: snapshot.weatherCode))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.58))
                        .lineLimit(1)
                    if !snapshot.highLowText.isEmpty {
                        Text(snapshot.highLowText)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.48))
                            .monospacedDigit()
                    }
                }

                Spacer(minLength: 0)

                temperatureDisplay(snapshot)
            }

            HStack(spacing: 8) {
                WeatherMetricPill(icon: "thermometer.medium", text: "Feels \(snapshot.apparentText)")
                WeatherMetricPill(icon: "humidity.fill", text: "\(snapshot.humidity)%")
                WeatherMetricPill(icon: "wind", text: snapshot.windText)
            }

            HStack {
                Text("Updated \(relativeTime(snapshot.fetchedAt))")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.36))
                Spacer()
                Text("Open-Meteo")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.36))
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: 8) {
            Spacer()
            ProgressView().controlSize(.small)
            Text("Fetching weather...")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var errorState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "cloud.sun.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.orange)
            Text(weather.errorMessage ?? "Weather unavailable")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
            Text("Check Weather settings.")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.52))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func temperatureDisplay(_ snapshot: WeatherSnapshot) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text("\(snapshot.temperatureNumberText)°")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .contentTransition(.numericText())
            Text(snapshot.unitLetter)
                .font(.system(size: 24, weight: .bold, design: .rounded))
        }
        .monospacedDigit()
        .foregroundColor(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(1)
    }

    private func relativeTime(_ date: Date) -> String {
        let minutes = max(0, Int(Date().timeIntervalSince(date) / 60))
        if minutes < 1 { return "now" }
        return "\(minutes)m ago"
    }

    private func weatherSymbol(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...57: return "cloud.drizzle.fill"
        case 61...67, 80...82: return "cloud.rain.fill"
        case 71...77, 85...86: return "snowflake"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.sun.fill"
        }
    }

    private func conditionText(for code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1: return "Mostly clear"
        case 2: return "Partly cloudy"
        case 3: return "Cloudy"
        case 45, 48: return "Fog"
        case 51...57: return "Drizzle"
        case 61...67: return "Rain"
        case 71...77: return "Snow"
        case 80...82: return "Showers"
        case 85...86: return "Snow showers"
        case 95...99: return "Thunderstorm"
        default: return "Weather"
        }
    }

    private func weatherColor(for code: Int) -> Color {
        switch code {
        case 0...2: return .yellow
        case 45, 48: return .gray
        case 51...67, 80...82: return .blue
        case 71...77, 85...86: return .cyan
        case 95...99: return .purple
        default: return .orange
        }
    }
}

struct WeatherMetricPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(text)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundColor(.white.opacity(0.68))
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

struct MediaSectionHeader: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color)
                .frame(width: 26, height: 26)
                .background(color.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white.opacity(0.42))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }
}

struct MediaArtwork: View {
    let urlString: String?
    let fallbackIcon: String
    let color: Color
    var size: CGFloat = 38

    var body: some View {
        Group {
            if let urlString, let url = URL(string: urlString), !urlString.isEmpty {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color.opacity(0.16))
                }
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.14))
                    .overlay(
                        Image(systemName: fallbackIcon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(color.opacity(0.9))
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct MediaConnectPrompt: View {
    let icon: String
    let title: String
    let subtitle: String
    let buttonTitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        VStack(spacing: 9) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 48, height: 48)
                .background(color.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
            Text(subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.48))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Button(action: action) {
                Text(buttonTitle)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 26)
                    .background(color.opacity(0.88))
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct SpotifyQueueWidget: View {
    @ObservedObject var nowPlaying: NowPlayingManager
    @StateObject private var spotifyManager = SpotifyAuthManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if spotifyManager.accessToken.isEmpty {
                let hasClientID = spotifyManager.hasValidClientID
                MediaConnectPrompt(
                    icon: hasClientID ? "music.note" : "lock.fill",
                    title: hasClientID ? "Sign in to Spotify" : "Setup Required",
                    subtitle: hasClientID ? "Access your queue directly from the notch." : "Open Settings to set your Client ID.",
                    buttonTitle: hasClientID ? "Connect Spotify" : "Open Settings",
                    color: hasClientID ? .green : .gray
                ) {
                        if hasClientID {
                            spotifyManager.authenticate { _ in }
                        } else {
                            UserDefaults.standard.set("Plugins", forKey: "lastSettingsTab")
                            SettingsWindowManager.shared.showSettings()
                        }
                }
            } else if spotifyManager.currentQueueItems.isEmpty {
                emptyStateView(text: "Fetching Spotify queue...", icon: "list.bullet.indent", color: .green)
            } else {
                MediaSectionHeader(
                    icon: "list.bullet.indent",
                    title: "Spotify Queue",
                    subtitle: "\(spotifyManager.currentQueueItems.count) upcoming",
                    color: .green
                )

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(spotifyManager.currentQueueItems.prefix(50).enumerated()), id: \.offset) { index, item in
                            SpotifyQueueRow(index: index + 1, track: item.track) {
                                spotifyManager.skipToQueueItem(index: index)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            spotifyManager.fetchQueue()
        }
        .onReceive(Timer.publish(every: 5, on: .main, in: .common).autoconnect()) { _ in
            spotifyManager.fetchQueue()
        }
        .onChange(of: nowPlaying.currentSong) { _, _ in
            spotifyManager.fetchQueue()
        }
    }
    
    private func emptyStateView(text: String, icon: String, color: Color) -> some View {
        VStack {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(color.opacity(0.72))
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.52))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct SpotifyQueueRow: View {
    let index: Int
    let track: SpotifyTrack
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text("\(index)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(isHovering ? .green : .white.opacity(0.42))
                    .frame(width: 12, alignment: .trailing)
                
                MediaArtwork(
                    urlString: track.album?.images?.first?.url,
                    fallbackIcon: "music.note",
                    color: .green,
                    size: 34
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    if isHovering {
                        MarqueeText(text: track.name, font: .system(size: 12, weight: .bold), alignment: .leading)
                            .foregroundColor(.green)
                            .frame(height: 14)
                    } else {
                        Text(track.name)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .frame(height: 14, alignment: .leading)
                    }
                    Text(track.artists.first?.name ?? "Unknown Artist")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                
                if isHovering {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.green)
                        .frame(width: 18, height: 18)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.vertical, 6)
            .background(isHovering ? Color.green.opacity(0.11) : Color.white.opacity(0.055))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

struct PlaceholderWidget: View {
    let name: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.accentColor)
            
            Text("\(name)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - YouTube Music Widgets

struct YouTubeQueueWidget: View {
    @ObservedObject var nowPlaying: NowPlayingManager
    @StateObject private var ytManager = YouTubeMusicManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if ytManager.accessToken.isEmpty {
                MediaConnectPrompt(
                    icon: "play.circle.fill",
                    title: "Sign in to YouTube Music",
                    subtitle: "Access your queue directly from the notch.",
                    buttonTitle: "Connect Account",
                    color: .red
                ) {
                    ytManager.authenticate { _ in }
                }
            } else if ytManager.currentPlaylistTracks.isEmpty {
                VStack {
                    Spacer()
                    Image(systemName: "play.square.stack")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.red.opacity(0.72))
                    Text("Fetching library...")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.52))
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                MediaSectionHeader(
                    icon: "play.square.stack",
                    title: "YouTube Queue",
                    subtitle: "\(ytManager.currentPlaylistTracks.count) tracks",
                    color: .red
                )

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(ytManager.currentPlaylistTracks.prefix(50).enumerated()), id: \.element.id) { index, item in
                            YTQueueRow(index: index + 1, item: item) {
                                ytManager.play(videoId: item.videoId, playlistId: item.playlistId, index: index)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct YTQueueRow: View {
    let index: Int
    let item: YTQueueItem
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text("\(index)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(isHovering ? .red : .white.opacity(0.42))
                    .frame(width: 22, alignment: .center)
                
                MediaArtwork(
                    urlString: item.imageURL,
                    fallbackIcon: "play.fill",
                    color: .red,
                    size: 38
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    if isHovering {
                        MarqueeText(text: item.title, font: .system(size: 12, weight: .bold), alignment: .leading)
                            .foregroundColor(.red)
                            .frame(height: 14)
                    } else {
                        Text(item.title)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .frame(height: 14, alignment: .leading)
                    }
                    Text(item.artist)
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 0)

                Image(systemName: "play.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(isHovering ? .red : .white.opacity(0.30))
                    .frame(width: 22, height: 22)
                    .background(Color.white.opacity(isHovering ? 0.10 : 0.04))
                    .clipShape(Circle())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(isHovering ? Color.red.opacity(0.11) : Color.white.opacity(0.055))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

struct YouTubePlaylistsWidget: View {
    @ObservedObject var nowPlaying: NowPlayingManager
    @StateObject private var ytManager = YouTubeMusicManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if ytManager.accessToken.isEmpty {
                MediaConnectPrompt(
                    icon: "play.rectangle.on.rectangle.fill",
                    title: "YouTube Playlists",
                    subtitle: "Sign in to access your library.",
                    buttonTitle: "Connect Account",
                    color: .red
                ) {
                    ytManager.authenticate { _ in }
                }
            } else {
                MediaSectionHeader(
                    icon: "play.rectangle.on.rectangle.fill",
                    title: "YouTube Playlists",
                    subtitle: "\(ytManager.playlists.count) playlists",
                    color: .red
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ytManager.playlists) { playlist in
                            YouTubePlaylistCard(playlist: playlist) {
                                ytManager.playPlaylist(playlistId: playlist.id)
                                ytManager.fetchPlaylistItems(playlistId: playlist.id)
                            }
                        }
                    }
                }
                .frame(height: 84)
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct YouTubePlaylistCard: View {
    let playlist: YTPlaylist
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        let artworkSize: CGFloat = 56

        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                MediaArtwork(
                    urlString: playlist.snippet.thumbnails?.medium?.url ?? playlist.snippet.thumbnails?.default?.url,
                    fallbackIcon: "play.rectangle.on.rectangle.fill",
                    color: .red,
                    size: artworkSize
                )

                Text(playlist.snippet.title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isHovering ? .red : .white)
                    .lineLimit(1)
                    .frame(width: artworkSize, alignment: .leading)
            }
            .frame(width: artworkSize, alignment: .leading)
            .padding(5)
            .background(isHovering ? Color.red.opacity(0.10) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovering = hovering
            }
        }
    }
}
