import SwiftUI
import Combine

struct NotchTaskItem: Codable, Identifiable, Equatable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    let createdAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

final class TasksManager: ObservableObject {
    static let shared = TasksManager()

    @Published private(set) var tasks: [NotchTaskItem] = []

    private let defaults = UserDefaults.standard

    private enum Key {
        static let storedTasks = "tasks_items"
        static let taskLimit = "tasks_limit"
        static let showCompleted = "tasks_show_completed"
    }

    private init() {
        loadTasks()
    }

    var taskLimit: Int {
        let stored = defaults.integer(forKey: Key.taskLimit)
        return min(max(stored > 0 ? stored : 30, 5), 100)
    }

    var showCompleted: Bool {
        defaults.object(forKey: Key.showCompleted) as? Bool ?? true
    }

    var incompleteCount: Int {
        tasks.filter { !$0.isCompleted }.count
    }

    var visibleTasks: [NotchTaskItem] {
        showCompleted ? tasks : tasks.filter { !$0.isCompleted }
    }

    func add(title rawTitle: String) {
        let title = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
            tasks.insert(NotchTaskItem(title: title), at: 0)
            pruneToLimit()
        }
        persistTasks()
    }

    func toggle(_ task: NotchTaskItem) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            tasks[index].isCompleted.toggle()
            tasks[index].completedAt = tasks[index].isCompleted ? Date() : nil
            sortTasks()
        }
        persistTasks()
    }

    func delete(_ task: NotchTaskItem) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            tasks.removeAll { $0.id == task.id }
        }
        persistTasks()
    }

    func clearCompleted() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            tasks.removeAll { $0.isCompleted }
        }
        persistTasks()
    }

    func clearAll() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
            tasks.removeAll()
        }
        persistTasks()
    }

    func syncSettings() {
        let taskCount = tasks.count
        pruneToLimit()
        if tasks.count != taskCount {
            persistTasks()
        } else {
            objectWillChange.send()
        }
    }

    private func sortTasks() {
        tasks.sort { left, right in
            if left.isCompleted != right.isCompleted {
                return !left.isCompleted
            }
            return left.createdAt > right.createdAt
        }
    }

    private func pruneToLimit() {
        if tasks.count > taskLimit {
            tasks = Array(tasks.prefix(taskLimit))
        }
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
}

struct TasksWidget: View {
    @StateObject private var manager = TasksManager.shared
    @State private var draftTitle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            inputRow

            if manager.visibleTasks.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 7) {
                        ForEach(manager.visibleTasks) { task in
                            TaskRow(task: task)
                                .transition(
                                    .asymmetric(
                                        insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.94)),
                                        removal: .move(edge: .trailing).combined(with: .opacity).combined(with: .scale(scale: 0.92))
                                    )
                                )
                        }
                    }
                    .animation(.spring(response: 0.34, dampingFraction: 0.78), value: manager.visibleTasks)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            manager.syncSettings()
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.mint)
                .scaleEffect(manager.incompleteCount == 0 && !manager.tasks.isEmpty ? 1.15 : 1)
                .rotationEffect(.degrees(manager.incompleteCount == 0 && !manager.tasks.isEmpty ? -8 : 0))
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: manager.incompleteCount)
            Text("Tasks")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
            Text("\(manager.incompleteCount)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .monospacedDigit()
            Spacer()
            Button {
                manager.clearCompleted()
            } label: {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Clear Completed")
            .disabled(!manager.tasks.contains(where: { $0.isCompleted }))
        }
    }

    private var inputRow: some View {
        HStack(spacing: 6) {
            TextField("Add a task", text: $draftTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onSubmit(addDraftTask)

            Button(action: addDraftTask) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 28, height: 28)
                    .background(Color.mint)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Add Task")
            .disabled(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.mint.opacity(0.85))
            Text(manager.tasks.isEmpty ? "No tasks yet." : "No active tasks.")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func addDraftTask() {
        manager.add(title: draftTitle)
        draftTitle = ""
    }
}

struct TaskRow: View {
    let task: NotchTaskItem
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            Button {
                TasksManager.shared.toggle(task)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(task.isCompleted ? .mint : .white.opacity(0.45))
                    .frame(width: 18, height: 18)
                    .scaleEffect(task.isCompleted ? 1.08 : 1)
                    .animation(.spring(response: 0.24, dampingFraction: 0.62), value: task.isCompleted)
            }
            .buttonStyle(.plain)
            .help(task.isCompleted ? "Mark Incomplete" : "Complete Task")

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(task.isCompleted ? .white.opacity(0.45) : .white)
                    .strikethrough(task.isCompleted, color: .white.opacity(0.35))
                    .lineLimit(1)

                Text(relativeTime)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                TasksManager.shared.delete(task)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(isHovering ? 0.55 : 0.35))
                    .frame(width: 18, height: 18)
                    .background(Color.white.opacity(isHovering ? 0.08 : 0.04))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Remove")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(isHovering ? Color.white.opacity(0.10) : Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .scaleEffect(isHovering ? 1.015 : 1)
        .offset(x: isHovering ? 2 : 0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private var relativeTime: String {
        let referenceDate = task.completedAt ?? task.createdAt
        let seconds = max(0, Int(Date().timeIntervalSince(referenceDate)))
        let prefix = task.isCompleted ? "Done " : "Added "

        if seconds < 60 { return prefix + "now" }
        let minutes = seconds / 60
        if minutes < 60 { return prefix + "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return prefix + "\(hours)h ago" }
        return prefix + "\(hours / 24)d ago"
    }
}
