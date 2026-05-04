import SwiftUI
import AppKit
import Combine
import UniformTypeIdentifiers

struct FileTrayItem: Codable, Identifiable, Equatable {
    let id: UUID
    let path: String
    let addedAt: Date

    init(id: UUID = UUID(), path: String, addedAt: Date = Date()) {
        self.id = id
        self.path = URL(fileURLWithPath: path).standardizedFileURL.path
        self.addedAt = addedAt
    }

    var url: URL {
        URL(fileURLWithPath: path)
    }

    var name: String {
        url.lastPathComponent.isEmpty ? path : url.lastPathComponent
    }

    var parentName: String {
        url.deletingLastPathComponent().lastPathComponent
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: path)
    }

    var isDirectory: Bool {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }

    var detailText: String {
        if !exists { return "Missing" }
        if isDirectory { return parentName.isEmpty ? "Folder" : "Folder in \(parentName)" }

        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size > 0 else { return parentName }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

final class FileTrayManager: ObservableObject {
    static let shared = FileTrayManager()

    @Published private(set) var items: [FileTrayItem] = []

    private let defaults = UserDefaults.standard
    private let pasteboard = NSPasteboard.general

    private enum Key {
        static let storedItems = "file_tray_items"
        static let trayLimit = "file_tray_limit"
    }

    private enum Constants {
        static let fileNamesPasteboardType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        static let urlTypeIdentifiers = [
            UTType.fileURL.identifier,
            UTType.url.identifier,
            NSPasteboard.PasteboardType.fileURL.rawValue,
            NSPasteboard.PasteboardType.URL.rawValue
        ]
        static let textTypeIdentifiers = [
            UTType.utf8PlainText.identifier,
            UTType.plainText.identifier,
            NSPasteboard.PasteboardType.string.rawValue
        ]
    }

    private init() {
        loadItems()
    }

    var trayLimit: Int {
        let stored = defaults.integer(forKey: Key.trayLimit)
        return min(max(stored > 0 ? stored : 24, 4), 80)
    }

    func add(urls: [URL]) {
        let newItems = urls
            .filter(\.isFileURL)
            .map { FileTrayItem(path: $0.path) }
            .filter { !$0.path.isEmpty }

        guard !newItems.isEmpty else { return }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
            for item in newItems.reversed() {
                items.removeAll { $0.path == item.path }
                items.insert(item, at: 0)
            }
            pruneToLimit()
        }

        persistItems()
    }

    func remove(_ item: FileTrayItem) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            items.removeAll { $0.id == item.id }
        }
        persistItems()
    }

    func clearItems() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            items.removeAll()
        }
        persistItems()
    }

    func syncSettings() {
        let itemCount = items.count
        pruneToLimit()
        if items.count != itemCount {
            persistItems()
        }
    }

    func open(_ item: FileTrayItem) {
        guard item.exists else { return }
        NSWorkspace.shared.open(item.url)
    }

    func reveal(_ item: FileTrayItem) {
        if item.exists {
            NSWorkspace.shared.activateFileViewerSelecting([item.url])
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([item.url.deletingLastPathComponent()])
        }
    }

    func copyToPasteboard(_ item: FileTrayItem) {
        guard item.exists else { return }
        pasteboard.clearContents()
        pasteboard.writeObjects([item.url as NSURL])
    }

    func add(from providers: [NSItemProvider]) -> Bool {
        var acceptedDrop = false

        for provider in providers {
            if let typeIdentifier = Constants.urlTypeIdentifiers.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) {
                acceptedDrop = true
                provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, _ in
                    guard let url = data.flatMap(self.fileURL(from:)) else { return }
                    DispatchQueue.main.async {
                        self.add(urls: [url])
                    }
                }
                provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                    guard let url = self.fileURL(from: item) else { return }
                    DispatchQueue.main.async {
                        self.add(urls: [url])
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(NSPasteboard.PasteboardType("NSFilenamesPboardType").rawValue) {
                acceptedDrop = true
                provider.loadItem(forTypeIdentifier: NSPasteboard.PasteboardType("NSFilenamesPboardType").rawValue, options: nil) { item, _ in
                    let urls = self.fileURLs(fromFileNamesItem: item)
                    guard !urls.isEmpty else { return }
                    DispatchQueue.main.async {
                        self.add(urls: urls)
                    }
                }
            } else if let typeIdentifier = Constants.textTypeIdentifiers.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) {
                acceptedDrop = true
                provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                    guard let url = self.fileURL(from: item) else { return }
                    DispatchQueue.main.async {
                        self.add(urls: [url])
                    }
                }
            }
        }

        return acceptedDrop
    }

    func addFromOpenPanel() {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.resolvesAliases = true
        panel.prompt = "Add"

        if panel.runModal() == .OK {
            add(urls: panel.urls)
        }
    }

    private func pruneToLimit() {
        if items.count > trayLimit {
            items = Array(items.prefix(trayLimit))
        }
    }

    private func loadItems() {
        guard let data = defaults.data(forKey: Key.storedItems),
              let decoded = try? JSONDecoder().decode([FileTrayItem].self, from: data) else {
            items = []
            return
        }
        items = Array(decoded.prefix(trayLimit))
    }

    private func persistItems() {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: Key.storedItems)
        }
    }

    private func fileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }
        if let url = item as? NSURL {
            return url as URL
        }
        if let data = item as? Data {
            return fileURL(from: data)
        }
        if let string = item as? String {
            return fileURL(from: string)
        }
        return nil
    }

    private func fileURL(from data: Data) -> URL? {
        if let url = URL(dataRepresentation: data, relativeTo: nil), url.isFileURL {
            return url
        }
        if let string = String(data: data, encoding: .utf8) {
            return fileURL(from: string)
        }
        return nil
    }

    private func fileURL(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.isFileURL {
            return url
        }

        if FileManager.default.fileExists(atPath: trimmed) {
            return URL(fileURLWithPath: trimmed)
        }

        return nil
    }

    private func fileURLs(fromFileNamesItem item: NSSecureCoding?) -> [URL] {
        if let paths = item as? [String] {
            return paths.map(URL.init(fileURLWithPath:))
        }
        if let data = item as? Data,
           let paths = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String] {
            return paths.map(URL.init(fileURLWithPath:))
        }
        if let string = item as? String {
            return [URL(fileURLWithPath: string)]
        }
        return []
    }
}

struct FileTrayWidget: View {
    @StateObject private var tray = FileTrayManager.shared
    @State private var isDropTargeted = false

    private let fileDropTypes = [
        UTType.fileURL.identifier,
        UTType.url.identifier,
        UTType.item.identifier,
        UTType.data.identifier,
        UTType.utf8PlainText.identifier,
        UTType.plainText.identifier,
        NSPasteboard.PasteboardType("NSFilenamesPboardType").rawValue
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "tray.full.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.cyan)
                    .scaleEffect(isDropTargeted ? 1.18 : 1)
                    .rotationEffect(.degrees(isDropTargeted ? -8 : 0))
                Text("File Tray")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                Text("\(tray.items.count)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .monospacedDigit()
                Spacer()
                Button {
                    tray.addFromOpenPanel()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Add Files")

                Button {
                    tray.clearItems()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Clear File Tray")
                .disabled(tray.items.isEmpty)
            }

            if tray.items.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        ForEach(tray.items) { item in
                            FileTrayRow(item: item)
                                .transition(
                                    .asymmetric(
                                        insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.94)),
                                        removal: .move(edge: .trailing).combined(with: .opacity).combined(with: .scale(scale: 0.92))
                                    )
                                )
                        }
                    }
                    .animation(.spring(response: 0.34, dampingFraction: 0.78), value: tray.items)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isDropTargeted ? Color.cyan.opacity(0.12) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isDropTargeted ? Color.cyan.opacity(0.65) : Color.clear, lineWidth: 1.5)
        )
        .overlay(
            FileTrayDropDestinationView(isTargeted: $isDropTargeted) { urls in
                tray.add(urls: urls)
            }
            .allowsHitTesting(false)
        )
        .onDrop(of: fileDropTypes, isTargeted: $isDropTargeted, perform: handleDrop)
        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isDropTargeted)
        .onReceive(NotificationCenter.default.publisher(for: .fileTrayDropTargetChanged)) { notification in
            let targeted = notification.userInfo?["isTargeted"] as? Bool ?? false
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                isDropTargeted = targeted
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            tray.syncSettings()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 25, weight: .semibold))
                .foregroundColor(.cyan.opacity(0.85))
            Text("Drop files or folders here.")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
            Button {
                tray.addFromOpenPanel()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                    Text("Add Files")
                }
                .font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        tray.add(from: providers)
    }
}

struct FileTrayDropDestinationView: NSViewRepresentable {
    @Binding var isTargeted: Bool
    let onDrop: ([URL]) -> Void

    func makeNSView(context: Context) -> FileTrayDropDestinationNSView {
        FileTrayDropDestinationNSView(
            onDrop: onDrop,
            setTargeted: { targeted in
                DispatchQueue.main.async {
                    isTargeted = targeted
                }
            }
        )
    }

    func updateNSView(_ nsView: FileTrayDropDestinationNSView, context: Context) {
        nsView.onDrop = onDrop
        nsView.setTargeted = { targeted in
            DispatchQueue.main.async {
                isTargeted = targeted
            }
        }
    }
}

final class FileTrayDropDestinationNSView: NSView {
    var onDrop: ([URL]) -> Void
    var setTargeted: (Bool) -> Void

    private let fileNamesPasteboardType = NSPasteboard.PasteboardType("NSFilenamesPboardType")

    init(onDrop: @escaping ([URL]) -> Void, setTargeted: @escaping (Bool) -> Void) {
        self.onDrop = onDrop
        self.setTargeted = setTargeted
        super.init(frame: .zero)
        registerForDraggedTypes([.fileURL, .URL, .string, fileNamesPasteboardType])
    }

    required init?(coder: NSCoder) {
        self.onDrop = { _ in }
        self.setTargeted = { _ in }
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .URL, .string, fileNamesPasteboardType])
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let urls = readURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else { return [] }
        setTargeted(true)
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        readURLs(from: sender.draggingPasteboard).isEmpty ? [] : .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        setTargeted(false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        setTargeted(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = readURLs(from: sender.draggingPasteboard)
        setTargeted(false)
        guard !urls.isEmpty else { return false }
        onDrop(urls)
        return true
    }

    private func readURLs(from pasteboard: NSPasteboard) -> [URL] {
        var urls: [URL] = []

        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [NSURL] {
            urls.append(contentsOf: fileURLs.map { $0 as URL })
        }

        if let paths = pasteboard.propertyList(forType: fileNamesPasteboardType) as? [String] {
            urls.append(contentsOf: paths.map(URL.init(fileURLWithPath:)))
        }

        if let urlString = pasteboard.string(forType: .URL),
           let url = URL(string: urlString),
           url.isFileURL {
            urls.append(url)
        }

        if let pathOrURL = pasteboard.string(forType: .string) {
            let trimmed = pathOrURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: trimmed), url.isFileURL {
                urls.append(url)
            } else if FileManager.default.fileExists(atPath: trimmed) {
                urls.append(URL(fileURLWithPath: trimmed))
            }
        }

        var seen = Set<String>()
        return urls.filter { url in
            guard url.isFileURL else { return false }
            let path = url.standardizedFileURL.path
            guard !seen.contains(path) else { return false }
            seen.insert(path)
            return true
        }
    }
}

struct FileTrayRow: View {
    let item: FileTrayItem
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                fileIcon

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(item.exists ? .white : .white.opacity(0.55))
                        .lineLimit(1)
                    Text(item.detailText)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(item.exists ? .white.opacity(0.48) : .orange.opacity(0.8))
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
            .overlay {
                FileTrayDragSourceView(item: item) {
                    FileTrayManager.shared.open(item)
                }
            }
            .help(item.exists ? "Open" : "File Missing")
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }

            actionButton(systemName: "doc.on.doc", help: "Copy File") {
                FileTrayManager.shared.copyToPasteboard(item)
            }
            .disabled(!item.exists)

            actionButton(systemName: "magnifyingglass", help: "Reveal in Finder") {
                FileTrayManager.shared.reveal(item)
            }

            actionButton(systemName: "xmark", help: "Remove") {
                FileTrayManager.shared.remove(item)
            }
        }
        .scaleEffect(isHovering ? 1.015 : 1)
        .offset(x: isHovering ? 2 : 0)
        .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isHovering)
    }

    private var fileIcon: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: item.path))
            .resizable()
            .scaledToFit()
            .opacity(item.exists ? 1.0 : 0.45)
            .frame(width: 24, height: 24)
            .frame(width: 30, height: 30)
    }

    private func actionButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.45))
                .frame(width: 18, height: 18)
                .background(Color.white.opacity(0.06))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var relativeTime: String {
        let seconds = max(0, Int(Date().timeIntervalSince(item.addedAt)))
        if seconds < 60 { return "now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        return "\(hours / 24)d"
    }
}

private struct FileTrayDragSourceView: NSViewRepresentable {
    let item: FileTrayItem
    let onClick: () -> Void

    func makeNSView(context: Context) -> FileTrayDragSourceNSView {
        let view = FileTrayDragSourceNSView()
        view.item = item
        view.onClick = onClick
        return view
    }

    func updateNSView(_ nsView: FileTrayDragSourceNSView, context: Context) {
        nsView.item = item
        nsView.onClick = onClick
    }
}

private final class FileTrayDragSourceNSView: NSView, NSDraggingSource {
    var item: FileTrayItem?
    var onClick: (() -> Void)?

    private var mouseDownEvent: NSEvent?
    private var didStartDrag = false
    private let dragThreshold: CGFloat = 3

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        didStartDrag = false
    }

    override func mouseUp(with event: NSEvent) {
        guard !didStartDrag else { return }
        onClick?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard !didStartDrag,
              let mouseDownEvent,
              let item,
              item.exists else {
            return
        }

        let startPoint = convert(mouseDownEvent.locationInWindow, from: nil)
        let currentPoint = convert(event.locationInWindow, from: nil)
        let distance = hypot(currentPoint.x - startPoint.x, currentPoint.y - startPoint.y)
        guard distance > dragThreshold else { return }

        didStartDrag = true
        beginFileDrag(for: item, at: currentPoint, event: event)
    }

    private func beginFileDrag(for item: FileTrayItem, at point: NSPoint, event: NSEvent) {
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(item.url.absoluteString, forType: .fileURL)
        pasteboardItem.setString(item.path, forType: .string)

        let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
        let icon = NSWorkspace.shared.icon(forFile: item.path)
        icon.size = NSSize(width: 48, height: 48)
        draggingItem.setDraggingFrame(
            NSRect(x: point.x - 24, y: point.y - 24, width: 48, height: 48),
            contents: icon
        )

        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        switch context {
        case .outsideApplication:
            return [.copy, .move]
        case .withinApplication:
            return [.copy]
        @unknown default:
            return [.copy]
        }
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
        false
    }
}
