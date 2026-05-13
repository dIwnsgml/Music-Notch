import SwiftUI
import AppKit
import CoreGraphics
import Combine

@MainActor
final class ScreenCaptureManager: ObservableObject {
    static let shared = ScreenCaptureManager()

    @Published private(set) var isBusy = false
    @Published private(set) var statusText = "Ready"
    @Published private(set) var lastCaptureURL: URL?
    @Published private(set) var lastError: String?
    @Published private(set) var hasScreenCapturePermission = CGPreflightScreenCaptureAccess()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let saveLocation = "screen_capture_save_location"
        static let imageFormat = "screen_capture_image_format"
        static let hideNotch = "screen_capture_hide_notch"
        static let includeCursor = "screen_capture_include_cursor"
        static let playSound = "screen_capture_play_sound"
        static let openAfterCapture = "screen_capture_open_after_capture"
        static let addToFileTray = "screen_capture_add_to_file_tray"
        static let recordingDuration = "screen_capture_recording_duration"
        static let recordAudio = "screen_capture_record_audio"
        static let showClicks = "screen_capture_show_clicks"
    }

    private init() {}

    var saveDirectory: URL {
        let base: FileManager.SearchPathDirectory
        switch defaults.string(forKey: Key.saveLocation) ?? "desktop" {
        case "downloads": base = .downloadsDirectory
        case "pictures": base = .picturesDirectory
        default: base = .desktopDirectory
        }

        return FileManager.default.urls(for: base, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
    }

    func refreshPermissionStatus() {
        hasScreenCapturePermission = CGPreflightScreenCaptureAccess()
    }

    func requestPermission() {
        hasScreenCapturePermission = CGRequestScreenCaptureAccess()
        if !hasScreenCapturePermission {
            openScreenRecordingSettings()
        }
    }

    func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }

    func openSaveLocation() {
        NSWorkspace.shared.open(saveDirectory)
    }

    func openLastCapture() {
        guard let lastCaptureURL else { return }
        NSWorkspace.shared.open(lastCaptureURL)
    }

    func revealLastCapture() {
        guard let lastCaptureURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastCaptureURL])
    }

    func captureFullScreen() {
        let outputURL = nextOutputURL(prefix: "WaveNotch Screenshot", extension: imageFormat)
        let arguments = screenshotArguments(outputURL: outputURL)
        runCapture(
            arguments: arguments,
            outputURL: outputURL,
            busyText: "Capturing screen...",
            successText: "Saved full screen"
        )
    }

    func captureSelection() {
        let outputURL = nextOutputURL(prefix: "WaveNotch Selection", extension: imageFormat)
        var arguments = screenshotArguments(outputURL: outputURL, includeCursor: false)
        arguments.insert("-s", at: 0)
        arguments.insert("-i", at: 0)
        runCapture(
            arguments: arguments,
            outputURL: outputURL,
            busyText: "Select an area...",
            successText: "Saved selection"
        )
    }

    func captureWindow() {
        let outputURL = nextOutputURL(prefix: "WaveNotch Window", extension: imageFormat)
        var arguments = screenshotArguments(outputURL: outputURL, includeCursor: false)
        arguments.insert("-w", at: 0)
        arguments.insert("-i", at: 0)
        runCapture(
            arguments: arguments,
            outputURL: outputURL,
            busyText: "Pick a window...",
            successText: "Saved window"
        )
    }

    func copyToClipboard() {
        var arguments = ["-c"]
        if boolSetting(Key.includeCursor, defaultValue: false) {
            arguments.append("-C")
        }
        if !boolSetting(Key.playSound, defaultValue: false) {
            arguments.append("-x")
        }

        runCapture(
            arguments: arguments,
            outputURL: nil,
            busyText: "Copying screenshot...",
            successText: "Copied to clipboard"
        )
    }

    func recordScreen() {
        let outputURL = nextOutputURL(prefix: "WaveNotch Recording", extension: "mov")
        var arguments = ["-v", "-i", "-Jvideo", "-U"]

        let duration = min(max(defaults.integer(forKey: Key.recordingDuration), 0), 600)
        if duration > 0 {
            arguments.append("-V\(duration)")
        }
        if boolSetting(Key.recordAudio, defaultValue: false) {
            arguments.append("-g")
        }
        if boolSetting(Key.showClicks, defaultValue: true) {
            arguments.append("-k")
        }
        if boolSetting(Key.openAfterCapture, defaultValue: false) {
            arguments.append("-P")
        }
        arguments.append(outputURL.path)

        runCapture(
            arguments: arguments,
            outputURL: outputURL,
            busyText: duration > 0 ? "Recording \(duration)s..." : "Recording screen...",
            successText: "Saved recording"
        )
    }

    private var imageFormat: String {
        let format = defaults.string(forKey: Key.imageFormat) ?? "png"
        return ["png", "jpg", "tiff", "pdf"].contains(format) ? format : "png"
    }

    private func screenshotArguments(outputURL: URL, includeCursor: Bool? = nil) -> [String] {
        var arguments: [String] = []
        if !boolSetting(Key.playSound, defaultValue: false) {
            arguments.append("-x")
        }
        if includeCursor ?? boolSetting(Key.includeCursor, defaultValue: false) {
            arguments.append("-C")
        }
        if boolSetting(Key.openAfterCapture, defaultValue: false) {
            arguments.append("-P")
        }
        arguments.append("-t\(imageFormat)")
        arguments.append(outputURL.path)
        return arguments
    }

    private func runCapture(arguments: [String], outputURL: URL?, busyText: String, successText: String) {
        guard !isBusy else { return }

        refreshPermissionStatus()
        isBusy = true
        statusText = busyText
        lastError = nil

        let shouldHideNotch = boolSetting(Key.hideNotch, defaultValue: true)

        Task {
            if shouldHideNotch {
                NotificationCenter.default.post(name: .screenCaptureWillStart, object: nil)
                try? await Task.sleep(nanoseconds: 180_000_000)
            }

            let result = await Self.runScreencapture(arguments: arguments)

            if shouldHideNotch {
                NotificationCenter.default.post(name: .screenCaptureDidFinish, object: nil)
            }

            finishCapture(result: result, outputURL: outputURL, successText: successText)
        }
    }

    private func finishCapture(result: CaptureProcessResult, outputURL: URL?, successText: String) {
        isBusy = false
        refreshPermissionStatus()

        if result.status == 0 {
            if let outputURL, FileManager.default.fileExists(atPath: outputURL.path) {
                lastCaptureURL = outputURL
                statusText = successText
                if boolSetting(Key.addToFileTray, defaultValue: false) {
                    FileTrayManager.shared.add(urls: [outputURL])
                }
            } else if outputURL == nil {
                statusText = successText
            } else {
                statusText = "Capture cancelled"
            }
            return
        }

        let cleanError = result.errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanError.localizedCaseInsensitiveContains("user canceled") || cleanError.isEmpty {
            statusText = "Capture cancelled"
        } else {
            statusText = "Capture failed"
            lastError = cleanError
        }
    }

    private func nextOutputURL(prefix: String, extension pathExtension: String) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let filename = "\(prefix) \(formatter.string(from: Date())).\(pathExtension)"
        try? FileManager.default.createDirectory(at: saveDirectory, withIntermediateDirectories: true)
        return saveDirectory.appendingPathComponent(filename)
    }

    private func boolSetting(_ key: String, defaultValue: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? defaultValue
    }

    private nonisolated static func runScreencapture(arguments: [String]) async -> CaptureProcessResult {
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            let errorPipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = arguments
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                return CaptureProcessResult(status: process.terminationStatus, errorOutput: errorOutput)
            } catch {
                return CaptureProcessResult(status: -1, errorOutput: error.localizedDescription)
            }
        }.value
    }
}

private struct CaptureProcessResult {
    let status: Int32
    let errorOutput: String
}

struct ScreenCaptureWidget: View {
    @StateObject private var manager = ScreenCaptureManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if !manager.hasScreenCapturePermission {
                permissionCard
            } else {
                actionGrid
                statusRow
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            manager.refreshPermissionStatus()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.cyan)

            Text("Screen Capture")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.9))

            Spacer()

            if manager.isBusy {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.78)
            } else {
                Button {
                    manager.openSaveLocation()
                } label: {
                    Image(systemName: "folder")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.55))
                }
                .buttonStyle(.plain)
                .help("Open Capture Folder")
            }
        }
    }

    private var permissionCard: some View {
        VStack(spacing: 9) {
            Spacer(minLength: 0)
            Image(systemName: "lock.rectangle.stack")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.cyan.opacity(0.9))
            Text("Screen Recording permission is needed.")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.72))
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                Button("Allow") {
                    manager.requestPermission()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Settings") {
                    manager.openScreenRecordingSettings()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var actionGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3), spacing: 7) {
            captureButton(title: "Screen", icon: "display", tint: .cyan) {
                manager.captureFullScreen()
            }
            captureButton(title: "Area", icon: "crop", tint: .blue) {
                manager.captureSelection()
            }
            captureButton(title: "Window", icon: "macwindow", tint: .purple) {
                manager.captureWindow()
            }
            captureButton(title: "Record", icon: "record.circle.fill", tint: .red) {
                manager.recordScreen()
            }
            captureButton(title: "Copy", icon: "doc.on.clipboard", tint: .green) {
                manager.copyToClipboard()
            }
            captureButton(title: "Open", icon: "arrow.up.forward.app", tint: .orange) {
                manager.openLastCapture()
            }
            .disabled(manager.lastCaptureURL == nil)
            .opacity(manager.lastCaptureURL == nil ? 0.45 : 1)
        }
        .disabled(manager.isBusy)
        .opacity(manager.isBusy ? 0.62 : 1)
    }

    private var statusRow: some View {
        HStack(spacing: 7) {
            Image(systemName: statusIcon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(statusColor)
                .frame(width: 16, height: 16)
                .background(statusColor.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(manager.statusText)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.72))
                    .lineLimit(1)

                if let lastCaptureURL = manager.lastCaptureURL {
                    Text(lastCaptureURL.lastPathComponent)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.white.opacity(0.38))
                        .lineLimit(1)
                } else if let error = manager.lastError {
                    Text(error)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.orange.opacity(0.75))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if manager.lastCaptureURL != nil {
                Button {
                    manager.revealLastCapture()
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.45))
                        .frame(width: 20, height: 20)
                        .background(Color.white.opacity(0.07))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Reveal Last Capture")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.055))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var statusIcon: String {
        if manager.isBusy { return "waveform" }
        if manager.lastError != nil { return "exclamationmark" }
        if manager.lastCaptureURL != nil { return "checkmark" }
        return "camera"
    }

    private var statusColor: Color {
        if manager.isBusy { return .cyan }
        if manager.lastError != nil { return .orange }
        if manager.lastCaptureURL != nil { return .green }
        return .white.opacity(0.45)
    }

    private func captureButton(title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(tint)
                    .frame(height: 16)
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.72))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 43)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.065))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
