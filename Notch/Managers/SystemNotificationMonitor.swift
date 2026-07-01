import AppKit
import ApplicationServices
import Combine
import Foundation

struct IslandSystemNotification: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let body: String
    let sourceAppName: String
    let receivedAt: Date
    let fingerprint: String
}

private struct NotificationWindowCandidate {
    let pid: pid_t
    let ownerName: String
}

final class SystemNotificationMonitor: ObservableObject {
    static let shared = SystemNotificationMonitor()

    @Published private(set) var activeNotification: IslandSystemNotification?
    @Published private(set) var hasAccessibilityPermission = AXIsProcessTrusted()

    private let queue = DispatchQueue(label: "com.wavenotch.system-notification-monitor", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var defaultsObserver: NSObjectProtocol?
    private var hideTask: Task<Void, Never>?
    private var recentFingerprints: [String: Date] = [:]
    private var isRunning = false
    private let dismissRetryDelays: [TimeInterval] = [0.02, 0.07, 0.14, 0.24, 0.38, 0.58, 0.85, 1.2, 1.7]
    private let commonNotificationSourceNames: Set<String> = [
        "airdrop",
        "arc",
        "calendar",
        "discord",
        "facetime",
        "finder",
        "firefox",
        "googlechrome",
        "instagram",
        "kakaotalk",
        "mail",
        "messages",
        "messenger",
        "music",
        "notion",
        "reminders",
        "safari",
        "signal",
        "slack",
        "spotify",
        "systemsettings",
        "telegram",
        "teams",
        "whatsapp",
        "xcode",
        "zoom"
    ]

    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "showSystemNotificationsInIsland") as? Bool ?? true
    }

    private var displayDuration: Double {
        let stored = UserDefaults.standard.double(forKey: "systemNotificationBannerDuration")
        return stored > 0 ? min(max(stored, 2.0), 10.0) : 5.0
    }

    private init() {
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshMonitoringState()
        }

        refreshMonitoringState()
    }

    deinit {
        stop()
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
    }

    func refreshMonitoringState() {
        let trusted = AXIsProcessTrusted()
        let enabled = isEnabled

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            if self.hasAccessibilityPermission != trusted {
                self.hasAccessibilityPermission = trusted
            }

            guard enabled, trusted else {
                self.stop()
                if self.activeNotification != nil {
                    self.activeNotification = nil
                }
                return
            }

            self.start()
        }
    }

    func dismissActiveNotification() {
        hideTask?.cancel()
        hideTask = nil

        DispatchQueue.main.async { [weak self] in
            guard let self, self.activeNotification != nil else { return }
            self.activeNotification = nil
        }
    }

    private func start() {
        guard !isRunning else { return }
        isRunning = true

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 0.12, repeating: 0.16, leeway: .milliseconds(45))
        timer.setEventHandler { [weak self] in
            self?.pollForNotification()
        }
        self.timer = timer
        timer.resume()
    }

    private func stop() {
        isRunning = false
        timer?.cancel()
        timer = nil
        hideTask?.cancel()
        hideTask = nil
    }

    private func pollForNotification() {
        pruneRecentFingerprints()

        guard let notification = captureLatestNotification(),
              recentFingerprints[notification.fingerprint] == nil else {
            return
        }

        recentFingerprints[notification.fingerprint] = Date()

        DispatchQueue.main.async { [weak self] in
            self?.publish(notification)
        }
    }

    private func captureLatestNotification() -> IslandSystemNotification? {
        let candidates = notificationWindowCandidates()
        guard !candidates.isEmpty else { return nil }

        let runningAppNames = Set(
            NSWorkspace.shared.runningApplications
                .compactMap(\.localizedName)
                .map { normalizeAppName($0) }
        )

        for candidate in candidates {
            if let notification = parseNotificationWindow(candidate, runningAppNames: runningAppNames) {
                return notification
            }
        }

        return nil
    }

    private func notificationWindowCandidates() -> [NotificationWindowCandidate] {
        guard let rawWindows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }

        var seenPIDs = Set<pid_t>()
        var candidates: [NotificationWindowCandidate] = []

        for window in rawWindows {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
                  let ownerName = window[kCGWindowOwnerName as String] as? String else {
                continue
            }

            let windowName = window[kCGWindowName as String] as? String ?? ""
            let searchableName = "\(ownerName) \(windowName)".lowercased()
            guard searchableName.contains("notification"),
                  !searchableName.contains("wavenotch"),
                  !seenPIDs.contains(ownerPID) else {
                continue
            }

            seenPIDs.insert(ownerPID)
            candidates.append(NotificationWindowCandidate(pid: ownerPID, ownerName: ownerName))
        }

        return candidates
    }

    private func parseNotificationWindow(
        _ candidate: NotificationWindowCandidate,
        runningAppNames: Set<String>
    ) -> IslandSystemNotification? {
        let appElement = AXUIElementCreateApplication(candidate.pid)
        var windowsRef: CFTypeRef?
        let windowResult = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)

        let windows = (windowResult == .success ? windowsRef as? [AXUIElement] : nil) ?? [appElement]

        for window in windows {
            var strings: [String] = []
            collectStrings(from: window, into: &strings)

            let significantStrings = significantNotificationStrings(strings)
            guard !significantStrings.isEmpty else { continue }

            let sourceAndContent = splitSourceAndContent(
                significantStrings,
                ownerName: candidate.ownerName,
                runningAppNames: runningAppNames
            )

            guard isValidNotificationContent(sourceAndContent) else { continue }

            let fingerprint = ([sourceAndContent.source, sourceAndContent.title, sourceAndContent.body])
                .map { normalizedFingerprintText($0) }
                .filter { !$0.isEmpty }
                .joined(separator: "|")

            guard !fingerprint.isEmpty else { continue }

            let notification = IslandSystemNotification(
                title: sourceAndContent.title,
                body: sourceAndContent.body,
                sourceAppName: sourceAndContent.source,
                receivedAt: Date(),
                fingerprint: fingerprint
            )

            scheduleNativeNotificationDismissal(appElement: appElement, window: window)
            return notification
        }

        return nil
    }

    private func collectStrings(from element: AXUIElement, into strings: inout [String], depth: Int = 0) {
        guard depth <= 7, strings.count < 80 else { return }

        let stringAttributes: [CFString] = [
            kAXTitleAttribute as CFString,
            kAXValueAttribute as CFString,
            kAXDescriptionAttribute as CFString,
            kAXHelpAttribute as CFString,
            "AXLabel" as CFString,
            "AXPlaceholderValue" as CFString
        ]

        for attribute in stringAttributes {
            var valueRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, attribute, &valueRef) == .success,
                  let value = valueRef else {
                continue
            }

            if let string = value as? String {
                strings.append(string)
            } else if let attributedString = value as? NSAttributedString {
                strings.append(attributedString.string)
            }
        }

        let childAttributes: [CFString] = [
            kAXChildrenAttribute as CFString,
            "AXContents" as CFString,
            "AXRows" as CFString,
            "AXVisibleChildren" as CFString
        ]

        for attribute in childAttributes {
            var childrenRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, attribute, &childrenRef) == .success,
                  let children = childrenRef as? [AXUIElement] else {
                continue
            }

            for child in children.prefix(30) {
                collectStrings(from: child, into: &strings, depth: depth + 1)
            }
        }
    }

    private func significantNotificationStrings(_ strings: [String]) -> [String] {
        var seen = Set<String>()

        return strings.compactMap { rawValue in
            let value = rawValue
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !value.isEmpty, value.count <= 220 else { return nil }

            let normalized = normalizedFingerprintText(value)
            guard !normalized.isEmpty,
                  !seen.contains(normalized),
                  !isGenericNotificationText(normalized),
                  !isTimeText(normalized) else {
                return nil
            }

            seen.insert(normalized)
            return value
        }
    }

    private func splitSourceAndContent(
        _ strings: [String],
        ownerName: String,
        runningAppNames: Set<String>
    ) -> (source: String, title: String, body: String) {
        var source = normalizeNotificationOwnerName(ownerName)
        var content = strings

        if let commaPrefixedNotification = parseCommaPrefixedNotification(strings, runningAppNames: runningAppNames) {
            source = commaPrefixedNotification.source
            content = commaPrefixedNotification.content
        } else if let first = strings.first {
            let normalizedFirst = normalizeAppName(first)
            if (runningAppNames.contains(normalizedFirst) || commonNotificationSourceNames.contains(normalizedFirst)), strings.count >= 2 {
                source = first
                content = Array(strings.dropFirst())
            }
        }

        let title = content.first ?? ""
        let body = content.dropFirst().prefix(2).joined(separator: " ")

        return (source, title, body)
    }

    private func isValidNotificationContent(_ content: (source: String, title: String, body: String)) -> Bool {
        let title = normalizedFingerprintText(content.title)
        let body = normalizedFingerprintText(content.body)
        let source = normalizedFingerprintText(content.source)

        guard !title.isEmpty,
              !isGenericNotificationText(title),
              !isNotificationCenterShellText(title) else {
            return false
        }

        if source == "notification", body.isEmpty, isLikelyNotificationCenterControlTitle(title) {
            return false
        }

        if isNotificationCenterShellText(body) {
            return false
        }

        return true
    }

    private func parseCommaPrefixedNotification(
        _ strings: [String],
        runningAppNames: Set<String>
    ) -> (source: String, content: [String])? {
        guard let first = strings.first else { return nil }

        let pieces = first
            .split(separator: ",", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard pieces.count >= 2 else { return nil }

        let source = pieces[0]
        let normalizedSource = normalizeAppName(source)
        let hasRelaySuffix = pieces.contains { isNotificationRelaySuffix($0) }
        let isKnownSource = runningAppNames.contains(normalizedSource) || commonNotificationSourceNames.contains(normalizedSource)

        guard hasRelaySuffix || isKnownSource else { return nil }

        var content = Array(strings.dropFirst())
        if content.isEmpty {
            let fallbackContent = pieces
                .dropFirst()
                .filter { !isNotificationRelaySuffix($0) }
                .joined(separator: ", ")

            if !fallbackContent.isEmpty {
                content = [fallbackContent]
            }
        }

        return (source, content)
    }

    private func publish(_ notification: IslandSystemNotification) {
        activeNotification = notification

        hideTask?.cancel()
        hideTask = Task { [weak self, notificationID = notification.id] in
            let duration = self?.displayDuration ?? 5.0
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard self?.activeNotification?.id == notificationID else { return }
                self?.activeNotification = nil
            }
        }
    }

    private func pruneRecentFingerprints() {
        let cutoff = Date().addingTimeInterval(-20 * 60)
        recentFingerprints = recentFingerprints.filter { $0.value > cutoff }
    }

    private func scheduleNativeNotificationDismissal(appElement: AXUIElement, window: AXUIElement) {
        dismissNativeNotificationWindow(window)
        dismissNativeNotificationWindow(appElement)
        dismissVisibleNativeNotifications()

        for delay in dismissRetryDelays {
            queue.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.dismissNativeNotificationWindow(window)
                self?.dismissNativeNotificationWindow(appElement)
                self?.dismissVisibleNativeNotifications()
            }
        }
    }

    private func dismissVisibleNativeNotifications() {
        for candidate in notificationWindowCandidates() {
            let appElement = AXUIElementCreateApplication(candidate.pid)
            dismissNativeNotificationWindow(appElement)

            var windowsRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                  let windows = windowsRef as? [AXUIElement] else {
                continue
            }

            for window in windows.prefix(8) {
                dismissNativeNotificationWindow(window)
            }
        }
    }

    private func dismissNativeNotificationWindow(_ element: AXUIElement) {
        if performDismissAction(on: element) {
            return
        }

        if AXUIElementPerformAction(element, "AXCancel" as CFString) == .success {
            return
        }

        _ = pressDismissControl(in: element)
    }

    private func performDismissAction(on element: AXUIElement) -> Bool {
        var actionsRef: CFArray?
        guard AXUIElementCopyActionNames(element, &actionsRef) == .success,
              let actions = actionsRef as? [String] else {
            return false
        }

        for action in actions {
            let normalized = normalizedFingerprintText(action)
            guard normalized.contains("cancel")
                    || normalized.contains("close")
                    || normalized.contains("dismiss") else {
                continue
            }

            if AXUIElementPerformAction(element, action as CFString) == .success {
                return true
            }
        }

        return false
    }

    private func pressDismissControl(in element: AXUIElement, depth: Int = 0) -> Bool {
        guard depth <= 8 else { return false }

        if isDismissControl(element),
           (performDismissAction(on: element) || AXUIElementPerformAction(element, kAXPressAction as CFString) == .success) {
                return true
        }

        let childAttributes: [CFString] = [
            kAXChildrenAttribute as CFString,
            "AXContents" as CFString,
            "AXRows" as CFString,
            "AXVisibleChildren" as CFString
        ]

        for attribute in childAttributes {
            var childrenRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, attribute, &childrenRef) == .success,
                  let children = childrenRef as? [AXUIElement] else {
                continue
            }

            for child in children.prefix(40) {
                if pressDismissControl(in: child, depth: depth + 1) {
                    return true
                }
            }
        }

        return false
    }

    private func isDismissControl(_ element: AXUIElement) -> Bool {
        let role = accessibilityStringAttribute(kAXRoleAttribute as CFString, from: element) ?? ""
        let subrole = accessibilityStringAttribute(kAXSubroleAttribute as CFString, from: element) ?? ""
        let searchable = [
            subrole,
            accessibilityStringAttribute(kAXTitleAttribute as CFString, from: element),
            accessibilityStringAttribute(kAXDescriptionAttribute as CFString, from: element),
            accessibilityStringAttribute(kAXHelpAttribute as CFString, from: element),
            accessibilityStringAttribute("AXLabel" as CFString, from: element)
        ]
            .compactMap { $0 }
            .map { normalizedFingerprintText($0) }
            .joined(separator: " ")

        let isButton = role == (kAXButtonRole as String) || normalizedFingerprintText(subrole).contains("button")
        guard isButton else { return false }

        return searchable.contains("close")
            || searchable.contains("dismiss")
            || searchable.contains("닫기")
    }

    private func accessibilityStringAttribute(_ attribute: CFString, from element: AXUIElement) -> String? {
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &valueRef) == .success,
              let value = valueRef else {
            return nil
        }

        if let string = value as? String {
            return string
        }

        if let attributedString = value as? NSAttributedString {
            return attributedString.string
        }

        return nil
    }

    private func normalizeNotificationOwnerName(_ ownerName: String) -> String {
        let normalized = ownerName
            .replacingOccurrences(of: "Notification Center", with: "")
            .replacingOccurrences(of: "NotificationCentre", with: "")
            .replacingOccurrences(of: "NotificationCenter", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return normalized.isEmpty ? "Notification" : normalized
    }

    private func normalizeAppName(_ appName: String) -> String {
        appName
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedFingerprintText(_ text: String) -> String {
        text
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isNotificationRelaySuffix(_ value: String) -> Bool {
        let normalized = normalizedFingerprintText(value)
        return normalized.hasPrefix("from ") || normalized == "iphone"
    }

    private func isGenericNotificationText(_ normalized: String) -> Bool {
        let genericValues: Set<String> = [
            "notification",
            "notifications",
            "notification center",
            "close",
            "clear",
            "clear all",
            "clear all notifications",
            "show",
            "show more",
            "show less",
            "options",
            "reply",
            "open",
            "dismiss",
            "notification settings",
            "settings",
            "widgets",
            "edit widgets"
        ]

        return genericValues.contains(normalized)
    }

    private func isNotificationCenterShellText(_ normalized: String) -> Bool {
        isGenericNotificationText(normalized)
            || normalized.hasPrefix("clear all")
            || normalized.hasSuffix("notifications")
            || normalized.contains("notification center")
    }

    private func isLikelyNotificationCenterControlTitle(_ normalized: String) -> Bool {
        normalized == "clear all"
            || normalized == "clear all notifications"
            || normalized == "notification center"
            || normalized == "notifications"
            || normalized == "widgets"
            || normalized == "edit widgets"
    }

    private func isTimeText(_ normalized: String) -> Bool {
        if normalized == "now" || normalized == "just now" { return true }
        if normalized.range(of: #"^\d+\s?(s|sec|m|min|h|hr|d|day)s?$"#, options: .regularExpression) != nil {
            return true
        }
        return false
    }
}
