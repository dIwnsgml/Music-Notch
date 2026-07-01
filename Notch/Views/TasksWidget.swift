import SwiftUI
import Combine
import UserNotifications

private func setTaskPopoverInteractionLock(_ locked: Bool) {
    NotificationCenter.default.post(
        name: .notchPluginInteractionLockChanged,
        object: nil,
        userInfo: ["isLocked": locked]
    )
}

enum NotchTaskPriority: Int, Codable, CaseIterable, Identifiable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .none: return "None"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var iconName: String {
        switch self {
        case .none: return "minus"
        case .low: return "exclamationmark"
        case .medium: return "exclamationmark.2"
        case .high: return "exclamationmark.3"
        }
    }

    var color: Color {
        switch self {
        case .none: return .white.opacity(0.42)
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        }
    }
}

struct NotchTaskSubtask: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var isCompleted: Bool

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }
}

struct NotchTaskList: Codable, Identifiable, Equatable {
    static let inboxID = UUID(uuidString: "A8DD5317-701B-46F5-A5DF-F682A8979E01")!

    enum ColorName: String, Codable, CaseIterable, Identifiable {
        case blue
        case mint
        case purple
        case pink
        case orange
        case red
        case gray

        var id: String { rawValue }

        var color: Color {
            switch self {
            case .blue: return .blue
            case .mint: return .mint
            case .purple: return .purple
            case .pink: return .pink
            case .orange: return .orange
            case .red: return .red
            case .gray: return .gray
            }
        }
    }

    let id: UUID
    var name: String
    var colorName: ColorName
    var iconName: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        colorName: ColorName = .blue,
        iconName: String = "list.bullet.circle.fill",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.colorName = colorName
        self.iconName = iconName
        self.createdAt = createdAt
    }

    var color: Color { colorName.color }

    static var inbox: NotchTaskList {
        NotchTaskList(
            id: inboxID,
            name: "Reminders",
            colorName: .blue,
            iconName: "list.bullet.circle.fill"
        )
    }
}

struct NotchTaskItem: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var notes: String
    var listID: UUID
    var isCompleted: Bool
    let createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var dueDate: Date?
    var hasTime: Bool
    var priority: NotchTaskPriority
    var isFlagged: Bool
    var tags: [String]
    var subtasks: [NotchTaskSubtask]

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        listID: UUID = NotchTaskList.inboxID,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil,
        dueDate: Date? = nil,
        hasTime: Bool = false,
        priority: NotchTaskPriority = .none,
        isFlagged: Bool = false,
        tags: [String] = [],
        subtasks: [NotchTaskSubtask] = []
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.listID = listID
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.dueDate = dueDate
        self.hasTime = hasTime
        self.priority = priority
        self.isFlagged = isFlagged
        self.tags = tags
        self.subtasks = subtasks
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case notes
        case listID
        case isCompleted
        case createdAt
        case updatedAt
        case completedAt
        case dueDate
        case hasTime
        case priority
        case isFlagged
        case tags
        case subtasks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        listID = try container.decodeIfPresent(UUID.self, forKey: .listID) ?? NotchTaskList.inboxID
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        self.createdAt = createdAt
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        hasTime = try container.decodeIfPresent(Bool.self, forKey: .hasTime) ?? false
        priority = try container.decodeIfPresent(NotchTaskPriority.self, forKey: .priority) ?? .none
        isFlagged = try container.decodeIfPresent(Bool.self, forKey: .isFlagged) ?? false
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        subtasks = try container.decodeIfPresent([NotchTaskSubtask].self, forKey: .subtasks) ?? []
    }

    var isScheduled: Bool { dueDate != nil }
    var incompleteSubtaskCount: Int { subtasks.filter { !$0.isCompleted }.count }
    var completedSubtaskCount: Int { subtasks.filter { $0.isCompleted }.count }
}

enum TaskSmartList: String, CaseIterable, Identifiable {
    case today
    case scheduled
    case all
    case flagged
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .scheduled: return "Scheduled"
        case .all: return "All"
        case .flagged: return "Flagged"
        case .completed: return "Done"
        }
    }

    var iconName: String {
        switch self {
        case .today: return "calendar.circle.fill"
        case .scheduled: return "calendar.badge.clock"
        case .all: return "tray.circle.fill"
        case .flagged: return "flag.circle.fill"
        case .completed: return "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .today: return .blue
        case .scheduled: return .red
        case .all: return .gray
        case .flagged: return .orange
        case .completed: return .mint
        }
    }
}

final class TasksManager: ObservableObject {
    static let shared = TasksManager()

    @Published private(set) var tasks: [NotchTaskItem] = []
    @Published private(set) var lists: [NotchTaskList] = []

    private let defaults = UserDefaults.standard
    private let calendar = Calendar.current
    private var reminderBannerTimers: [UUID: Timer] = [:]
    private var reminderScanTimer: Timer?
    private var lastSettingsSignature: String?

    private enum Key {
        static let storedTasks = "tasks_items"
        static let storedLists = "tasks_lists"
        static let taskLimit = "tasks_limit"
        static let showCompleted = "tasks_show_completed"
        static let notificationsEnabled = "tasks_reminder_notifications_enabled"
        static let appBannerEnabled = "tasks_reminder_app_banner_enabled"
        static let deliveredAppBannerKeys = "tasks_delivered_app_banner_keys"
    }

    private init() {
        loadLists()
        loadTasks()
        lastSettingsSignature = settingsSignature
        syncReminderNotifications()
    }

    var taskLimit: Int {
        let stored = defaults.integer(forKey: Key.taskLimit)
        return min(max(stored > 0 ? stored : 60, 5), 200)
    }

    var showCompleted: Bool {
        defaults.object(forKey: Key.showCompleted) as? Bool ?? true
    }

    var notificationsEnabled: Bool {
        defaults.object(forKey: Key.notificationsEnabled) as? Bool ?? true
    }

    var appBannerEnabled: Bool {
        defaults.object(forKey: Key.appBannerEnabled) as? Bool ?? true
    }

    var incompleteCount: Int {
        tasks.filter { !$0.isCompleted }.count
    }

    var visibleTasks: [NotchTaskItem] {
        filteredTasks(scope: TaskSmartList.all.rawValue, searchText: "")
    }

    func startReminderMonitoring() {
        requestSystemNotificationAuthorizationIfNeeded()
        syncReminderNotifications()
        guard reminderScanTimer == nil else { return }

        let timer = Timer(timeInterval: 10, repeats: true) { [weak self] _ in
            self?.deliverDueAppReminderBanners()
        }
        timer.tolerance = 2
        reminderScanTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func sendTestReminderAlerts() {
        let title = "WaveNotch reminder test"
        let body = "This is how task reminders will appear."

        if appBannerEnabled {
            NotificationCenter.default.post(
                name: .taskReminderBannerRequested,
                object: nil,
                userInfo: [
                    "taskID": UUID().uuidString,
                    "title": title,
                    "body": body
                ]
            )
        }

        guard notificationsEnabled else { return }
        let content = reminderNotificationContent(title: title, body: body, taskID: UUID())
        let request = UNNotificationRequest(
            identifier: "wavenotch.task.reminder.test.\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        submitSystemReminderNotification(request, showDeniedBanner: true)
    }

    func add(title rawTitle: String) {
        add(title: rawTitle, scope: TaskSmartList.all.rawValue)
    }

    func add(title rawTitle: String, scope: String) {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        let listID = listID(for: scope) ?? NotchTaskList.inboxID
        let task = NotchTaskItem(title: title, listID: listID)

        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
            tasks.insert(task, at: 0)
            sortTasks()
            pruneToLimit()
        }
        persistTasks()
        scheduleReminderNotificationIfNeeded(for: task)
    }

    func update(_ task: NotchTaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        var updated = task
        updated.title = updated.title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.notes = updated.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.tags = normalizedTags(updated.tags)
        guard !updated.title.isEmpty else { return }
        updated.updatedAt = Date()

        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            tasks[index] = updated
            sortTasks()
        }
        persistTasks()
        clearDeliveredAppBannerKeys(for: [updated.id])
        scheduleReminderNotificationIfNeeded(for: updated)
    }

    func toggle(_ task: NotchTaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            tasks[index].isCompleted.toggle()
            tasks[index].completedAt = tasks[index].isCompleted ? Date() : nil
            tasks[index].updatedAt = Date()
            sortTasks()
        }
        persistTasks()
        if tasks.first(where: { $0.id == task.id })?.isCompleted == true {
            cancelReminderAlerts(for: [task.id])
        } else if let updated = tasks.first(where: { $0.id == task.id }) {
            clearDeliveredAppBannerKeys(for: [updated.id])
            scheduleReminderNotificationIfNeeded(for: updated)
        }
    }

    func toggleFlag(_ task: NotchTaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            tasks[index].isFlagged.toggle()
            tasks[index].updatedAt = Date()
            sortTasks()
        }
        persistTasks()
    }

    func delete(_ task: NotchTaskItem) {
        cancelReminderAlerts(for: [task.id])
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            tasks.removeAll { $0.id == task.id }
        }
        persistTasks()
    }

    func clearCompleted() {
        cancelReminderAlerts(for: tasks.filter(\.isCompleted).map(\.id))
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            tasks.removeAll { $0.isCompleted }
        }
        persistTasks()
    }

    func clearAll() {
        cancelReminderAlerts(for: tasks.map(\.id))
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            tasks.removeAll()
        }
        persistTasks()
    }

    func addList(name rawName: String, colorName: NotchTaskList.ColorName) -> NotchTaskList? {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        let list = NotchTaskList(name: name, colorName: colorName)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            lists.append(list)
        }
        persistLists()
        return list
    }

    func deleteList(_ list: NotchTaskList) {
        guard list.id != NotchTaskList.inboxID else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            tasks = tasks.map { task in
                var updated = task
                if updated.listID == list.id {
                    updated.listID = NotchTaskList.inboxID
                }
                return updated
            }
            lists.removeAll { $0.id == list.id }
        }
        persistTasks()
        persistLists()
    }

    func syncSettings() {
        let signature = settingsSignature
        let settingsChanged = lastSettingsSignature != signature
        lastSettingsSignature = signature

        let taskCount = tasks.count
        pruneToLimit()
        let didPrune = tasks.count != taskCount

        if didPrune {
            persistTasks()
        } else if settingsChanged {
            objectWillChange.send()
        }

        guard settingsChanged || didPrune else { return }
        syncReminderNotifications()
    }

    func filteredTasks(scope: String, searchText: String) -> [NotchTaskItem] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = tasks.filter { task in
            let scopeMatches = matches(scope: scope, task: task)
            let searchMatches = trimmedSearch.isEmpty || matches(search: trimmedSearch, task: task)
            return scopeMatches && searchMatches
        }
        return sorted(filtered, completedMode: scope == TaskSmartList.completed.rawValue)
    }

    func scopeTitle(_ scope: String) -> String {
        if let smartList = TaskSmartList(rawValue: scope) {
            return smartList.title
        }
        if let listID = listID(for: scope), let list = list(with: listID) {
            return list.name
        }
        return TaskSmartList.all.title
    }

    func scopeIcon(_ scope: String) -> String {
        if let smartList = TaskSmartList(rawValue: scope) {
            return smartList.iconName
        }
        if let listID = listID(for: scope), let list = list(with: listID) {
            return list.iconName
        }
        return TaskSmartList.all.iconName
    }

    func scopeColor(_ scope: String) -> Color {
        if let smartList = TaskSmartList(rawValue: scope) {
            return smartList.color
        }
        if let listID = listID(for: scope), let list = list(with: listID) {
            return list.color
        }
        return TaskSmartList.all.color
    }

    func scopeCount(_ scope: String) -> Int {
        filteredTasks(scope: scope, searchText: "").count
    }

    func list(with id: UUID) -> NotchTaskList? {
        lists.first { $0.id == id }
    }

    func listScopeKey(_ id: UUID) -> String {
        "list:\(id.uuidString)"
    }

    func isValidScope(_ scope: String) -> Bool {
        if TaskSmartList(rawValue: scope) != nil { return true }
        guard let listID = listID(for: scope) else { return false }
        return lists.contains { $0.id == listID }
    }

    func dueText(for task: NotchTaskItem) -> String? {
        guard let dueDate = task.dueDate else { return nil }
        let prefix: String
        if calendar.isDateInToday(dueDate) {
            prefix = task.hasTime ? "Today \(timeFormatter.string(from: dueDate))" : "Today"
        } else if calendar.isDateInTomorrow(dueDate) {
            prefix = task.hasTime ? "Tomorrow \(timeFormatter.string(from: dueDate))" : "Tomorrow"
        } else if calendar.isDateInYesterday(dueDate) {
            prefix = task.hasTime ? "Yesterday \(timeFormatter.string(from: dueDate))" : "Yesterday"
        } else {
            prefix = task.hasTime
                ? "\(dateFormatter.string(from: dueDate)) \(timeFormatter.string(from: dueDate))"
                : dateFormatter.string(from: dueDate)
        }
        return prefix
    }

    func dueColor(for task: NotchTaskItem) -> Color {
        guard let dueDate = task.dueDate, !task.isCompleted else { return .white.opacity(0.42) }
        if dueDate < calendar.startOfDay(for: Date()) { return .red }
        if calendar.isDateInToday(dueDate) { return .blue }
        return .white.opacity(0.48)
    }

    private func matches(scope: String, task: NotchTaskItem) -> Bool {
        if let smartList = TaskSmartList(rawValue: scope) {
            switch smartList {
            case .today:
                guard !task.isCompleted, let dueDate = task.dueDate else { return false }
                return calendar.isDateInToday(dueDate) || dueDate < calendar.startOfDay(for: Date())
            case .scheduled:
                return !task.isCompleted && task.dueDate != nil
            case .all:
                return showCompleted || !task.isCompleted
            case .flagged:
                return !task.isCompleted && task.isFlagged
            case .completed:
                return task.isCompleted
            }
        }

        if let listID = listID(for: scope) {
            return task.listID == listID && (showCompleted || !task.isCompleted)
        }

        return showCompleted || !task.isCompleted
    }

    private func matches(search: String, task: NotchTaskItem) -> Bool {
        let listName = list(with: task.listID)?.name ?? ""
        let haystack = [
            task.title,
            task.notes,
            listName,
            task.tags.joined(separator: " "),
            task.subtasks.map(\.title).joined(separator: " ")
        ]
            .joined(separator: " ")
            .lowercased()
        return haystack.contains(search)
    }

    private func sorted(_ source: [NotchTaskItem], completedMode: Bool) -> [NotchTaskItem] {
        source.sorted { left, right in
            if completedMode {
                return (left.completedAt ?? left.updatedAt) > (right.completedAt ?? right.updatedAt)
            }
            if left.isCompleted != right.isCompleted { return !left.isCompleted }
            if overdueOrToday(left) != overdueOrToday(right) { return overdueOrToday(left) }
            if left.isFlagged != right.isFlagged { return left.isFlagged }
            if left.priority.rawValue != right.priority.rawValue { return left.priority.rawValue > right.priority.rawValue }

            switch (left.dueDate, right.dueDate) {
            case let (.some(leftDate), .some(rightDate)) where leftDate != rightDate:
                return leftDate < rightDate
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            default:
                return left.updatedAt > right.updatedAt
            }
        }
    }

    private func overdueOrToday(_ task: NotchTaskItem) -> Bool {
        guard !task.isCompleted, let dueDate = task.dueDate else { return false }
        return calendar.isDateInToday(dueDate) || dueDate < calendar.startOfDay(for: Date())
    }

    private func sortTasks() {
        tasks = sorted(tasks, completedMode: false)
    }

    private func pruneToLimit() {
        if tasks.count > taskLimit {
            cancelReminderAlerts(for: Array(tasks.dropFirst(taskLimit)).map(\.id))
            tasks = Array(tasks.prefix(taskLimit))
        }
    }

    private func loadLists() {
        guard let data = defaults.data(forKey: Key.storedLists),
              let decoded = try? JSONDecoder().decode([NotchTaskList].self, from: data) else {
            lists = [.inbox]
            persistLists()
            return
        }

        var decodedLists = decoded
        if !decodedLists.contains(where: { $0.id == NotchTaskList.inboxID }) {
            decodedLists.insert(.inbox, at: 0)
        }
        lists = decodedLists
    }

    private func loadTasks() {
        guard let data = defaults.data(forKey: Key.storedTasks),
              let decoded = try? JSONDecoder().decode([NotchTaskItem].self, from: data) else {
            tasks = []
            return
        }
        tasks = Array(decoded.prefix(taskLimit))
        sortTasks()
    }

    private func persistTasks() {
        if let data = try? JSONEncoder().encode(tasks) {
            defaults.set(data, forKey: Key.storedTasks)
        }
    }

    private func persistLists() {
        if let data = try? JSONEncoder().encode(lists) {
            defaults.set(data, forKey: Key.storedLists)
        }
    }

    private func syncReminderNotifications() {
        requestSystemNotificationAuthorizationIfNeeded()

        if !notificationsEnabled {
            cancelSystemReminderNotifications(for: tasks.map(\.id))
        }

        if !appBannerEnabled {
            cancelReminderBanners(for: tasks.map(\.id))
        }

        for task in tasks {
            scheduleReminderNotificationIfNeeded(for: task)
        }
        deliverDueAppReminderBanners()
    }

    private func scheduleReminderNotificationIfNeeded(for task: NotchTaskItem) {
        cancelSystemReminderNotifications(for: [task.id])
        cancelReminderBanners(for: [task.id])
        guard (notificationsEnabled || appBannerEnabled),
              !task.isCompleted,
              let fireDate = reminderFireDate(for: task) else {
            return
        }

        let listName = list(with: task.listID)?.name
        guard fireDate > Date().addingTimeInterval(1) else {
            if appBannerEnabled {
                deliverAppReminderBannerIfNeeded(for: task, fireDate: fireDate, listName: listName)
            }
            return
        }

        if notificationsEnabled {
            scheduleSystemReminderNotification(for: task, fireDate: fireDate, listName: listName)
        }

        if appBannerEnabled {
            scheduleAppReminderBanner(for: task, fireDate: fireDate, listName: listName)
        }
    }

    private func scheduleSystemReminderNotification(for task: NotchTaskItem, fireDate: Date, listName: String?) {
        let identifier = reminderNotificationIdentifier(for: task.id)
        let content = reminderNotificationContent(
            title: task.title,
            body: notificationBody(for: task, listName: listName),
            taskID: task.id
        )
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, fireDate.timeIntervalSinceNow), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        submitSystemReminderNotification(request, showDeniedBanner: false)
    }

    private func reminderNotificationContent(title: String, body: String, taskID: UUID) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = "wavenotch.tasks"
        content.categoryIdentifier = "TASK_REMINDER"
        content.userInfo = ["taskID": taskID.uuidString]
        if #available(macOS 12.0, *) {
            content.interruptionLevel = .timeSensitive
        }
        return content
    }

    private func submitSystemReminderNotification(_ request: UNNotificationRequest, showDeniedBanner: Bool) {
        let center = UNUserNotificationCenter.current()

        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                center.add(request) { error in
                    if let error {
                        print("Failed to schedule task notification: \(error.localizedDescription)")
                    }
                }
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    guard granted else {
                        if showDeniedBanner {
                            self.postNotificationPermissionBanner()
                        }
                        return
                    }
                    center.add(request) { error in
                        if let error {
                            print("Failed to schedule task notification: \(error.localizedDescription)")
                        }
                    }
                }
            case .denied:
                if showDeniedBanner {
                    self.postNotificationPermissionBanner()
                }
                break
            @unknown default:
                break
            }
        }
    }

    private func postNotificationPermissionBanner() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .taskReminderBannerRequested,
                object: nil,
                userInfo: [
                    "taskID": UUID().uuidString,
                    "title": "macOS notifications are off",
                    "body": "Allow WaveNotch notifications in System Settings."
                ]
            )
        }
    }

    private func requestSystemNotificationAuthorizationIfNeeded() {
        guard notificationsEnabled else { return }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        }
    }

    private func scheduleAppReminderBanner(for task: NotchTaskItem, fireDate: Date, listName: String?) {
        let interval = max(0.1, fireDate.timeIntervalSinceNow)
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self, taskID = task.id] _ in
            guard let self else { return }
            guard self.appBannerEnabled,
                  let currentTask = self.tasks.first(where: { $0.id == taskID }),
                  !currentTask.isCompleted else {
                self.reminderBannerTimers[taskID] = nil
                return
            }

            self.deliverAppReminderBannerIfNeeded(
                for: currentTask,
                fireDate: self.reminderFireDate(for: currentTask) ?? fireDate,
                listName: self.list(with: currentTask.listID)?.name ?? listName
            )
            self.reminderBannerTimers[taskID] = nil
        }
        timer.tolerance = min(30, max(1, interval * 0.05))
        reminderBannerTimers[task.id] = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func deliverDueAppReminderBanners() {
        guard appBannerEnabled else { return }

        let now = Date()
        for task in tasks {
            guard !task.isCompleted,
                  let fireDate = reminderFireDate(for: task),
                  fireDate <= now else { continue }

            deliverAppReminderBannerIfNeeded(for: task, fireDate: fireDate, listName: list(with: task.listID)?.name)
        }
    }

    private func deliverAppReminderBannerIfNeeded(for task: NotchTaskItem, fireDate: Date, listName: String?) {
        let key = appBannerDeliveryKey(for: task, fireDate: fireDate)
        var deliveredKeys = deliveredAppBannerKeys
        guard !deliveredKeys.contains(key) else { return }

        let body = notificationBody(for: task, listName: listName)
        postAppReminderBanner(for: task, body: body)
        deliveredKeys.insert(key)
        deliveredAppBannerKeys = deliveredKeys
    }

    private func postAppReminderBanner(for task: NotchTaskItem, body: String) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .taskReminderBannerRequested,
                object: nil,
                userInfo: [
                    "taskID": task.id.uuidString,
                    "title": task.title,
                    "body": body
                ]
            )
        }
    }

    private func cancelReminderAlerts(for taskIDs: [UUID]) {
        cancelSystemReminderNotifications(for: taskIDs)
        cancelReminderBanners(for: taskIDs)
        clearDeliveredAppBannerKeys(for: taskIDs)
    }

    private func cancelSystemReminderNotifications(for taskIDs: [UUID]) {
        let identifiers = taskIDs.map(reminderNotificationIdentifier)
        guard !identifiers.isEmpty else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func cancelReminderBanners(for taskIDs: [UUID]) {
        for taskID in taskIDs {
            reminderBannerTimers[taskID]?.invalidate()
            reminderBannerTimers[taskID] = nil
        }
    }

    private var deliveredAppBannerKeys: Set<String> {
        get {
            Set(defaults.stringArray(forKey: Key.deliveredAppBannerKeys) ?? [])
        }
        set {
            defaults.set(Array(newValue), forKey: Key.deliveredAppBannerKeys)
        }
    }

    private func clearDeliveredAppBannerKeys(for taskIDs: [UUID]) {
        guard !taskIDs.isEmpty else { return }
        let prefixes = taskIDs.map { "\($0.uuidString):" }
        let existingKeys = deliveredAppBannerKeys
        let filtered = existingKeys.filter { key in
            !prefixes.contains { key.hasPrefix($0) }
        }
        if filtered != existingKeys {
            deliveredAppBannerKeys = filtered
        }
    }

    private var settingsSignature: String {
        [
            "\(taskLimit)",
            "\(showCompleted)",
            "\(notificationsEnabled)",
            "\(appBannerEnabled)"
        ].joined(separator: "|")
    }

    private func appBannerDeliveryKey(for task: NotchTaskItem, fireDate: Date) -> String {
        "\(task.id.uuidString):\(Int(fireDate.timeIntervalSince1970))"
    }

    private func reminderNotificationIdentifier(for taskID: UUID) -> String {
        "wavenotch.task.reminder.\(taskID.uuidString)"
    }

    private func reminderFireDate(for task: NotchTaskItem) -> Date? {
        guard let dueDate = task.dueDate else { return nil }
        if task.hasTime { return dueDate }
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: dueDate)
    }

    private func notificationBody(for task: NotchTaskItem, listName: String?) -> String {
        var parts: [String] = []
        if let dueText = dueText(for: task) {
            parts.append(dueText)
        }
        if let listName, !listName.isEmpty {
            parts.append(listName)
        }
        if !task.notes.isEmpty {
            parts.append(task.notes)
        }
        return parts.isEmpty ? "Reminder due now." : parts.joined(separator: " - ")
    }

    private func listID(for scope: String) -> UUID? {
        guard scope.hasPrefix("list:") else { return nil }
        return UUID(uuidString: String(scope.dropFirst(5)))
    }

    private func normalizedTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        return tags.compactMap { tag in
            let cleaned = tag
                .replacingOccurrences(of: "#", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return nil }
            let key = cleaned.lowercased()
            guard !seen.contains(key) else { return nil }
            seen.insert(key)
            return cleaned
        }
    }

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }()

    private lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

struct TasksWidget: View {
    @StateObject private var manager = TasksManager.shared
    @AppStorage("tasks_selected_scope") private var selectedScope = TaskSmartList.all.rawValue
    @State private var draftTitle = ""
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var isCreatingList = false
    @State private var isShowingActions = false

    private var visibleTasks: [NotchTaskItem] {
        manager.filteredTasks(scope: selectedScope, searchText: searchText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            scopeRail

            if isSearching {
                searchRow
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            quickAddRow

            if visibleTasks.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 7) {
                        ForEach(visibleTasks) { task in
                            ReminderTaskRow(manager: manager, task: task)
                                .transition(
                                    .asymmetric(
                                        insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.96)),
                                        removal: .move(edge: .trailing).combined(with: .opacity).combined(with: .scale(scale: 0.94))
                                    )
                                )
                        }
                    }
                    .animation(.spring(response: 0.34, dampingFraction: 0.8), value: visibleTasks)
                    .padding(.bottom, 2)
                }
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: ensureValidSelection)
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            DispatchQueue.main.async {
                manager.syncSettings()
                ensureValidSelection()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.mint)
                .frame(width: 28, height: 28)
                .background(Color.mint.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 0) {
                Text(manager.scopeTitle(selectedScope))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("\(visibleTasks.count) \(visibleTasks.count == 1 ? "reminder" : "reminders")")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.52))
                    .monospacedDigit()
            }

            Spacer(minLength: 6)

            Button {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                    isSearching.toggle()
                    if !isSearching { searchText = "" }
                }
            } label: {
                Image(systemName: isSearching ? "xmark" : "magnifyingglass")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.68))
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(isSearching ? 0.14 : 0.07))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(isSearching ? "Close Search" : "Search Reminders")

            Button {
                setTaskPopoverInteractionLock(true)
                isShowingActions = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.68))
                    .frame(width: 26, height: 26)
                    .background(Color.white.opacity(0.07))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isShowingActions) {
                TaskActionsPopover(manager: manager) {
                    isShowingActions = false
                }
                .onAppear {
                    setTaskPopoverInteractionLock(true)
                }
                .onDisappear {
                    setTaskPopoverInteractionLock(false)
                }
            }
            .onChange(of: isShowingActions) { _, isOpen in
                setTaskPopoverInteractionLock(isOpen)
            }
            .help("Task Actions")
        }
    }

    private var scopeRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(TaskSmartList.allCases) { smartList in
                    TaskScopeChip(
                        title: smartList.title,
                        iconName: smartList.iconName,
                        color: smartList.color,
                        count: manager.scopeCount(smartList.rawValue),
                        isSelected: selectedScope == smartList.rawValue
                    ) {
                        selectedScope = smartList.rawValue
                    }
                }

                Rectangle()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 1, height: 20)
                    .padding(.horizontal, 2)

                ForEach(manager.lists) { list in
                    TaskScopeChip(
                        title: list.name,
                        iconName: list.iconName,
                        color: list.color,
                        count: manager.scopeCount(manager.listScopeKey(list.id)),
                        isSelected: selectedScope == manager.listScopeKey(list.id)
                    ) {
                        selectedScope = manager.listScopeKey(list.id)
                    }
                }

                Button {
                    setTaskPopoverInteractionLock(true)
                    isCreatingList = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 28, height: 24)
                        .background(Color.white.opacity(0.07))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .popover(isPresented: $isCreatingList) {
                    NewTaskListPopover(manager: manager) { list in
                        selectedScope = manager.listScopeKey(list.id)
                        isCreatingList = false
                    }
                    .onAppear {
                        setTaskPopoverInteractionLock(true)
                    }
                    .onDisappear {
                        setTaskPopoverInteractionLock(false)
                    }
                }
                .onChange(of: isCreatingList) { _, isOpen in
                    setTaskPopoverInteractionLock(isOpen)
                }
                .help("New List")
            }
            .padding(.vertical, 1)
        }
    }

    private var searchRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(0.42))
            TextField("Search title, notes, tags", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var quickAddRow: some View {
        HStack(spacing: 6) {
            TextField("New Reminder", text: $draftTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .onSubmit(addDraftTask)

            Button(action: addDraftTask) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.black)
                    .frame(width: 28, height: 28)
                    .background(Color.mint)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Add Reminder")
            .disabled(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 7) {
            Spacer(minLength: 4)
            Image(systemName: emptyIconName)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(Color.mint.opacity(0.82))
            Text(emptyTitle)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.66))
            Text(emptySubtitle)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.38))
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Spacer(minLength: 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyIconName: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "magnifyingglass" }
        if selectedScope == TaskSmartList.completed.rawValue { return "checkmark.seal.fill" }
        return "checklist"
    }

    private var emptyTitle: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "No matches" }
        if selectedScope == TaskSmartList.today.rawValue { return "Nothing due today" }
        if selectedScope == TaskSmartList.completed.rawValue { return "No completed reminders" }
        return "No reminders"
    }

    private var emptySubtitle: String {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Try another title, note, tag, or list."
        }
        return "Add a reminder or create a list."
    }

    private func addDraftTask() {
        manager.add(title: draftTitle, scope: selectedScope)
        draftTitle = ""
    }

    private func ensureValidSelection() {
        if !manager.isValidScope(selectedScope) {
            selectedScope = TaskSmartList.all.rawValue
        }
    }
}

private struct TaskScopeChip: View {
    let title: String
    let iconName: String
    let color: Color
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: iconName)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(isSelected ? color : .white.opacity(0.52))
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.62))
                    .lineLimit(1)
                Text("\(count)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .white.opacity(0.72) : .white.opacity(0.36))
                    .monospacedDigit()
            }
            .padding(.horizontal, 8)
            .frame(height: 24)
            .background(isSelected ? color.opacity(0.22) : Color.white.opacity(0.06))
            .overlay(
                Capsule()
                    .stroke(isSelected ? color.opacity(0.45) : Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct TaskActionsPopover: View {
    @ObservedObject var manager: TasksManager
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                manager.clearCompleted()
                close()
            } label: {
                Label("Clear Completed", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!manager.tasks.contains(where: { $0.isCompleted }))

            Button(role: .destructive) {
                manager.clearAll()
                close()
            } label: {
                Label("Clear All", systemImage: "trash")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(12)
        .frame(width: 190)
    }
}

private struct ReminderTaskRow: View {
    @ObservedObject var manager: TasksManager
    let task: NotchTaskItem
    @AppStorage("tasks_detail_display_mode") private var detailDisplayMode = "compact"
    @State private var isHovering = false
    @State private var isEditing = false

    private var shouldShowInlineDetails: Bool {
        detailDisplayMode == "always" || (detailDisplayMode == "hover" && isHovering)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            completeButton

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    if task.priority != .none {
                        Image(systemName: task.priority.iconName)
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(task.priority.color)
                    }

                    Text(task.title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(task.isCompleted ? .white.opacity(0.42) : .white)
                        .strikethrough(task.isCompleted, color: .white.opacity(0.35))
                        .lineLimit(1)
                }

                metadataRow

                if shouldShowInlineDetails {
                    TaskInlineDetails(manager: manager, task: task)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Spacer(minLength: 4)

            Button {
                manager.toggleFlag(task)
            } label: {
                Image(systemName: task.isFlagged ? "flag.fill" : "flag")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(task.isFlagged ? .orange : .white.opacity(isHovering ? 0.5 : 0.24))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .help(task.isFlagged ? "Unflag" : "Flag")

            Button {
                openEditor()
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(isHovering ? 0.6 : 0.32))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isEditing) {
                TaskDetailEditor(manager: manager, task: manager.tasks.first(where: { $0.id == task.id }) ?? task)
                    .onAppear {
                        setTaskPopoverInteractionLock(true)
                    }
                    .onDisappear {
                        setTaskPopoverInteractionLock(false)
                    }
            }
            .onChange(of: isEditing) { _, isOpen in
                setTaskPopoverInteractionLock(isOpen)
            }
            .help("Edit Details")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(isHovering ? Color.white.opacity(0.105) : Color.white.opacity(0.052))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(task.isFlagged ? Color.orange.opacity(0.28) : Color.white.opacity(isHovering ? 0.14 : 0.06), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .scaleEffect(isHovering ? 1.01 : 1)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.14)) {
                isHovering = hovering
            }
        }
            .contextMenu {
            Button(task.isCompleted ? "Mark Incomplete" : "Mark Complete") {
                manager.toggle(task)
            }
            Button(task.isFlagged ? "Unflag" : "Flag") {
                manager.toggleFlag(task)
            }
            Button("Edit Details") {
                openEditor()
            }
            Button(role: .destructive) {
                manager.delete(task)
            } label: {
                Text("Delete")
            }
        }
        .onTapGesture(count: 2) {
            openEditor()
        }
    }

    private func openEditor() {
        setTaskPopoverInteractionLock(true)
        isEditing = true
    }

    private var completeButton: some View {
        Button {
            manager.toggle(task)
        } label: {
            ZStack {
                Circle()
                    .stroke(task.isCompleted ? Color.mint : Color.white.opacity(0.38), lineWidth: 1.8)
                    .frame(width: 18, height: 18)
                if task.isCompleted {
                    Circle()
                        .fill(Color.mint)
                        .frame(width: 18, height: 18)
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.black)
                }
            }
            .frame(width: 28, height: 28)
            .contentShape(Circle())
            .scaleEffect(task.isCompleted ? 1.06 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.62), value: task.isCompleted)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .help(task.isCompleted ? "Mark Incomplete" : "Complete")
    }

    private var metadataRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                if let dueText = manager.dueText(for: task) {
                    TaskMetadataPill(
                        iconName: "calendar",
                        text: dueText,
                        color: manager.dueColor(for: task)
                    )
                }

                if let list = manager.list(with: task.listID) {
                    TaskMetadataPill(
                        iconName: list.iconName,
                        text: list.name,
                        color: list.color.opacity(0.82)
                    )
                }

                ForEach(Array(task.tags.prefix(2)), id: \.self) { tag in
                    TaskMetadataPill(
                        iconName: "number",
                        text: tag,
                        color: .white.opacity(0.46)
                    )
                }

                if !task.notes.isEmpty {
                    TaskMetadataPill(iconName: "note.text", text: "note", color: .white.opacity(0.42))
                }

                if !task.subtasks.isEmpty {
                    TaskMetadataPill(
                        iconName: "checklist",
                        text: "\(task.completedSubtaskCount)/\(task.subtasks.count)",
                        color: task.incompleteSubtaskCount == 0 ? .mint : .white.opacity(0.46)
                    )
                }
            }
        }
        .frame(height: 17)
    }
}

private struct TaskInlineDetails: View {
    @ObservedObject var manager: TasksManager
    let task: NotchTaskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                if let dueText = manager.dueText(for: task) {
                    Label(dueText, systemImage: "bell.fill")
                        .foregroundColor(manager.dueColor(for: task))
                }

                if task.priority != .none {
                    Label(task.priority.title, systemImage: task.priority.iconName)
                        .foregroundColor(task.priority.color)
                }
            }
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .lineLimit(1)

            if !task.notes.isEmpty {
                Text(task.notes)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.52))
                    .lineLimit(2)
            }

            if !task.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(task.tags.prefix(4), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.52))
                            .padding(.horizontal, 5)
                            .frame(height: 14)
                            .background(Color.white.opacity(0.07))
                            .clipShape(Capsule())
                    }
                }
            }

            if !task.subtasks.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(task.subtasks.prefix(2)) { subtask in
                        HStack(spacing: 4) {
                            Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(subtask.isCompleted ? .mint : .white.opacity(0.36))
                            Text(subtask.title)
                                .font(.system(size: 8, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.48))
                                .strikethrough(subtask.isCompleted, color: .white.opacity(0.3))
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(.top, 1)
        .animation(.easeInOut(duration: 0.16), value: shouldAnimateKey)
    }

    private var shouldAnimateKey: String {
        "\(task.id)-\(task.notes)-\(task.tags.joined())-\(task.subtasks.count)"
    }
}

private struct TaskMetadataPill: View {
    let iconName: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: iconName)
                .font(.system(size: 7, weight: .bold))
            Text(text)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .lineLimit(1)
        }
        .foregroundColor(color)
        .padding(.horizontal, 5)
        .frame(height: 15)
        .background(color.opacity(0.11))
        .clipShape(Capsule())
    }
}

private struct TaskDetailEditor: View {
    @ObservedObject var manager: TasksManager
    @Environment(\.dismiss) private var dismiss
    @State private var draft: NotchTaskItem
    @State private var tagText: String
    @State private var newSubtaskTitle = ""

    init(manager: TasksManager, task: NotchTaskItem) {
        self.manager = manager
        _draft = State(initialValue: task)
        _tagText = State(initialValue: task.tags.joined(separator: ", "))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Reminder Details")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
            }

            TextField("Title", text: $draft.title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                Picker("List", selection: $draft.listID) {
                    ForEach(manager.lists) { list in
                        Text(list.name).tag(list.id)
                    }
                }
                .pickerStyle(.menu)

                Toggle(isOn: $draft.isFlagged) {
                    Label("Flag", systemImage: draft.isFlagged ? "flag.fill" : "flag")
                }
                .toggleStyle(.checkbox)
            }

            Picker("Priority", selection: $draft.priority) {
                ForEach(NotchTaskPriority.allCases) { priority in
                    Label(priority.title, systemImage: priority.iconName).tag(priority)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Date", isOn: dueDateEnabled)
                    .toggleStyle(.checkbox)

                if draft.dueDate != nil {
                    let pickerComponents: DatePickerComponents = draft.hasTime ? [.date, .hourAndMinute] : [.date]
                    DatePicker("Due", selection: dueDateBinding, displayedComponents: pickerComponents)
                    Toggle("Time", isOn: $draft.hasTime)
                        .toggleStyle(.checkbox)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Tags")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                TextField("study, work, errands", text: $tagText)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Notes")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                TextEditor(text: $draft.notes)
                    .font(.system(size: 11, weight: .medium))
                    .frame(height: 54)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Subtasks")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)

                ForEach(draft.subtasks) { subtask in
                    HStack(spacing: 6) {
                        Button {
                            toggleSubtask(subtask)
                        } label: {
                            Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .buttonStyle(.plain)

                        Text(subtask.title)
                            .font(.system(size: 10, weight: .semibold))
                            .strikethrough(subtask.isCompleted)
                            .lineLimit(1)

                        Spacer()

                        Button {
                            draft.subtasks.removeAll { $0.id == subtask.id }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 6) {
                    TextField("New subtask", text: $newSubtaskTitle)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addSubtask)

                    Button(action: addSubtask) {
                        Image(systemName: "plus")
                    }
                    .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            HStack {
                Button(role: .destructive) {
                    manager.delete(draft)
                    dismiss()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Save") {
                    save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(width: 342)
    }

    private var dueDateBinding: Binding<Date> {
        Binding(
            get: { draft.dueDate ?? Date() },
            set: { draft.dueDate = $0 }
        )
    }

    private var dueDateEnabled: Binding<Bool> {
        Binding(
            get: { draft.dueDate != nil },
            set: { enabled in
                if enabled {
                    draft.dueDate = draft.dueDate ?? Date()
                } else {
                    draft.dueDate = nil
                    draft.hasTime = false
                }
            }
        )
    }

    private func addSubtask() {
        let title = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        draft.subtasks.append(NotchTaskSubtask(title: title))
        newSubtaskTitle = ""
    }

    private func toggleSubtask(_ subtask: NotchTaskSubtask) {
        guard let index = draft.subtasks.firstIndex(where: { $0.id == subtask.id }) else { return }
        draft.subtasks[index].isCompleted.toggle()
    }

    private func save() {
        draft.tags = tagText
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        manager.update(draft)
    }
}

private struct NewTaskListPopover: View {
    @ObservedObject var manager: TasksManager
    let onCreate: (NotchTaskList) -> Void
    @State private var name = ""
    @State private var selectedColor: NotchTaskList.ColorName = .blue

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New List")
                .font(.system(size: 14, weight: .bold, design: .rounded))

            TextField("List name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit(create)

            HStack(spacing: 8) {
                ForEach(NotchTaskList.ColorName.allCases) { colorName in
                    Button {
                        selectedColor = colorName
                    } label: {
                        Circle()
                            .fill(colorName.color)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Circle()
                                    .stroke(selectedColor == colorName ? Color.primary : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                create()
            } label: {
                Label("Create List", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(14)
        .frame(width: 220)
    }

    private func create() {
        guard let list = manager.addList(name: name, colorName: selectedColor) else { return }
        name = ""
        onCreate(list)
    }
}
