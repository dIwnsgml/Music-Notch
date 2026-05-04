import SwiftUI
import AppKit
import SkyLightWindow
import Sparkle
import PostHog

extension SkyLightOperator {
    func undelegateWindow(_ window: NSWindow) {
        typealias RemoveWindowsFromSpaces = @convention(c) (Int32, CFArray, CFArray) -> Int32

        let handler = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight", RTLD_NOW)
        guard let removeWindowsFromSpaces = unsafeBitCast(
            dlsym(handler, "SLSRemoveWindowsFromSpaces"),
            to: RemoveWindowsFromSpaces?.self
        ) else {
            return
        }

        _ = removeWindowsFromSpaces(
            connection,
            [window.windowNumber] as CFArray,
            [space] as CFArray
        )
    }
}

extension Notification.Name {
    static let fileTrayDropTargetChanged = Notification.Name("FileTrayDropTargetChanged")
    static let fileTrayDropCompleted = Notification.Name("FileTrayDropCompleted")
    static let pomodoroSessionCompleted = Notification.Name("PomodoroSessionCompleted")
}

@main
struct DynamicIslandApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @AppStorage("enableAnalytics") var enableAnalytics = true
    
    init() {
        let configuration = PostHogConfig(
            apiKey: "phc_tptR6JFYUrtWPDsY4Mo2rZNF9BHnUduUirV58uaLpAjT",
            host: "https://us.i.posthog.com"
        )
        PostHogSDK.shared.setup(configuration)
        
        if !enableAnalytics {
            PostHogSDK.shared.optOut()
        } else {
            PostHogSDK.shared.optIn()
            PostHogSDK.shared.capture("App Launched")
        }
    }
    
    var body: some Scene {
        MenuBarExtra("WaveNotch", systemImage: "music.note") {
            Button("Settings...") {
                SettingsWindowManager.shared.showSettings()
            }
            
            Button("Check for Updates...") {
                appDelegate.updaterController.checkForUpdates(nil)
            }
            
            Divider()
            
            Button("Quit WaveNotch") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

// ⚡️ URL Handling for OAuth
struct URLHandler: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onOpenURL { url in
                print("Received URL: \(url.absoluteString)")
                
                if url.scheme == "wavenotch" {
                    if url.host == "callback" {
                        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                           let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                            NotificationCenter.default.post(name: NSNotification.Name("SpotifyAuthCallback"), object: code)
                        }
                    }
                } else if url.scheme == "com.googleusercontent.apps.989490326013-4ukfahi6t9cplb3mujovrrbtb1onoif0" {
                    if url.path == "/google-callback" {
                        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                           let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                            NotificationCenter.default.post(name: NSNotification.Name("GoogleAuthCallback"), object: code)
                        }
                    } else if url.path == "/youtube-callback" {
                        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                           let code = components.queryItems?.first(where: { $0.name == "code" })?.value {
                            NotificationCenter.default.post(name: NSNotification.Name("YouTubeAuthCallback"), object: code)
                        }
                    }
                }
            }
    }
}

class IslandPanel: NSPanel {
    override var canBecomeKey: Bool { return true }
    override var canBecomeMain: Bool { return true }

    private let fileNamesPasteboardType = NSPasteboard.PasteboardType("NSFilenamesPboardType")

    @objc func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        dropOperation(for: sender, targeted: true)
    }

    @objc func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        dropOperation(for: sender, targeted: true)
    }

    @objc func draggingExited(_ sender: NSDraggingInfo?) {
        postDropTargeted(false)
    }

    @objc func draggingEnded(_ sender: NSDraggingInfo) {
        postDropTargeted(false)
    }

    @objc func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard UserDefaults.standard.bool(forKey: "plugin_file_tray_enabled") else {
            postDropTargeted(false)
            return false
        }
        guard isInsideDropColumn(sender) else {
            postDropTargeted(false)
            return false
        }

        let urls = fileDropURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else {
            postDropTargeted(false)
            return false
        }

        FileTrayManager.shared.add(urls: urls)
        NotificationCenter.default.post(
            name: .fileTrayDropCompleted,
            object: nil,
            userInfo: ["count": urls.count]
        )
        return true
    }

    private func dropOperation(for sender: NSDraggingInfo, targeted: Bool) -> NSDragOperation {
        guard UserDefaults.standard.bool(forKey: "plugin_file_tray_enabled") else {
            postDropTargeted(false)
            return NSDragOperation()
        }
        guard isInsideDropColumn(sender) else {
            postDropTargeted(false)
            return NSDragOperation()
        }

        let urls = fileDropURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else {
            postDropTargeted(false)
            return NSDragOperation()
        }

        postDropTargeted(targeted, count: urls.count)
        return .copy
    }

    private func isInsideDropColumn(_ sender: NSDraggingInfo) -> Bool {
        guard let contentView else { return true }
        let point = contentView.convert(sender.draggingLocation, from: nil)
        let dropWidth = min(contentView.bounds.width, 560)
        let dropRect = NSRect(
            x: (contentView.bounds.width - dropWidth) / 2,
            y: 0,
            width: dropWidth,
            height: contentView.bounds.height
        )
        return dropRect.contains(point)
    }

    private func postDropTargeted(_ targeted: Bool, count: Int = 0) {
        NotificationCenter.default.post(
            name: .fileTrayDropTargetChanged,
            object: nil,
            userInfo: ["isTargeted": targeted, "count": count]
        )
    }

    private func fileDropURLs(from pasteboard: NSPasteboard) -> [URL] {
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

final class DropHostingView<Content: View>: NSHostingView<Content> {
    private let fileNamesPasteboardType = NSPasteboard.PasteboardType("NSFilenamesPboardType")

    required init(rootView: Content) {
        super.init(rootView: rootView)
        registerForDraggedTypes([.fileURL, .URL, .string, fileNamesPasteboardType])
    }

    @MainActor required dynamic init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL, .URL, .string, fileNamesPasteboardType])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        dropOperation(for: sender, targeted: true)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        dropOperation(for: sender, targeted: true)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        postDropTargeted(false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        postDropTargeted(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard UserDefaults.standard.bool(forKey: "plugin_file_tray_enabled") else {
            postDropTargeted(false)
            return false
        }
        guard isInsideDropColumn(sender) else {
            postDropTargeted(false)
            return false
        }

        let urls = fileDropURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else {
            postDropTargeted(false)
            return false
        }

        FileTrayManager.shared.add(urls: urls)
        NotificationCenter.default.post(
            name: .fileTrayDropCompleted,
            object: nil,
            userInfo: ["count": urls.count]
        )
        return true
    }

    private func dropOperation(for sender: NSDraggingInfo, targeted: Bool) -> NSDragOperation {
        guard UserDefaults.standard.bool(forKey: "plugin_file_tray_enabled") else {
            postDropTargeted(false)
            return NSDragOperation()
        }
        guard isInsideDropColumn(sender) else {
            postDropTargeted(false)
            return NSDragOperation()
        }

        let urls = fileDropURLs(from: sender.draggingPasteboard)
        guard !urls.isEmpty else {
            postDropTargeted(false)
            return NSDragOperation()
        }

        postDropTargeted(targeted, count: urls.count)
        return .copy
    }

    private func isInsideDropColumn(_ sender: NSDraggingInfo) -> Bool {
        let point = convert(sender.draggingLocation, from: nil)
        let dropWidth = min(bounds.width, 560)
        let dropRect = NSRect(
            x: (bounds.width - dropWidth) / 2,
            y: 0,
            width: dropWidth,
            height: bounds.height
        )
        return dropRect.contains(point)
    }

    private func postDropTargeted(_ targeted: Bool, count: Int = 0) {
        NotificationCenter.default.post(
            name: .fileTrayDropTargetChanged,
            object: nil,
            userInfo: ["isTargeted": targeted, "count": count]
        )
    }

    private func fileDropURLs(from pasteboard: NSPasteboard) -> [URL] {
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

class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: IslandPanel!
    let updaterController: SPUStandardUpdaterController
    private var isSkyLightEnabled = false
    private var restoreSkyLightTask: Task<Void, Never>?
    
    override init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        super.init()
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        
        // ⚡️ Large transparent window to allow dynamic sizing of content within it
        let panelWidth: CGFloat = 1000 
        let panelHeight: CGFloat = 800
        
        panel = IslandPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow],
            backing: .buffered,
            defer: false
        )
        
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .ignoresCycle,
            .fullScreenAuxiliary
        ]
        
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovable = false
        panel.registerForDraggedTypes([.fileURL, .URL, .string, NSPasteboard.PasteboardType("NSFilenamesPboardType")])
        
        let hostingView = DropHostingView(rootView: ContentView().modifier(URLHandler()))
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        
        panel.contentView = hostingView
        
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()

        // ⚡️ Initial center
        centerPanel()
        DispatchQueue.main.async { [weak self] in
            self?.centerPanel()
            self?.enableSkyLight()
        }
        OnboardingWindowManager.shared.showIfNeeded()
        
        // ⚡️ Listen for layout changes to re-center the window
        NotificationCenter.default.addObserver(forName: NSNotification.Name("CenterAppWindow"), object: nil, queue: .main) { _ in
            self.centerPanel()
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name("UpdateNotchLayout"), object: nil, queue: .main) { _ in
            self.centerPanel()
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { _ in
            self.repositionAfterScreenChange()
        }
        NotificationCenter.default.addObserver(forName: NSWindow.didChangeScreenNotification, object: panel, queue: .main) { _ in
            self.repositionAfterScreenChange()
        }
        NotificationCenter.default.addObserver(forName: .fileTrayDropTargetChanged, object: nil, queue: .main) { notification in
            let targeted = notification.userInfo?["isTargeted"] as? Bool ?? false
            if targeted {
                self.disableSkyLight()
                self.centerPanel(on: self.screen(from: notification) ?? self.screenForMouse())
            } else {
                self.scheduleSkyLightRestore(after: 0.35)
            }
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowManager.shared.showSettings()
        return true
    }
    
    func centerPanel() {
        centerPanel(on: screenForPanel())
    }

    private func centerPanel(on screen: NSScreen?) {
        guard let screen else { return }

        let x = roundedToBackingPixel(screen.frame.midX - panel.frame.width / 2, on: screen)
        let y = roundedToBackingPixel(screen.frame.maxY - panel.frame.height, on: screen)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func screenForPanel() -> NSScreen? {
        if let screen = panel.screen {
            return screen
        }

        let panelCenter = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(panelCenter) }) {
            return screen
        }

        return NSScreen.main ?? NSScreen.screens.first
    }

    private func screenForMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func screen(from notification: Notification) -> NSScreen? {
        guard let rectValue = notification.userInfo?["screenFrame"] as? NSValue else { return nil }
        let frame = rectValue.rectValue
        return NSScreen.screens.first { $0.frame == frame }
            ?? NSScreen.screens.first { $0.frame.intersects(frame) }
    }

    private func roundedToBackingPixel(_ value: CGFloat, on screen: NSScreen) -> CGFloat {
        let scale = max(screen.backingScaleFactor, 1)
        return (value * scale).rounded() / scale
    }

    private func enableSkyLight() {
        guard !isSkyLightEnabled, panel != nil else { return }
        SkyLightOperator.shared.delegateWindow(panel)
        isSkyLightEnabled = true
    }

    private func disableSkyLight() {
        restoreSkyLightTask?.cancel()
        guard isSkyLightEnabled, panel != nil else { return }
        SkyLightOperator.shared.undelegateWindow(panel)
        isSkyLightEnabled = false
        panel.orderFrontRegardless()
    }

    private func scheduleSkyLightRestore(after seconds: Double) {
        restoreSkyLightTask?.cancel()
        restoreSkyLightTask = Task { [weak self] in
            let delay = UInt64(seconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.centerPanel()
                self?.enableSkyLight()
            }
        }
    }

    private func repositionAfterScreenChange() {
        disableSkyLight()
        centerPanel(on: screenForPanel() ?? NSScreen.main ?? NSScreen.screens.first)
        scheduleSkyLightRestore(after: 0.15)
    }
}
