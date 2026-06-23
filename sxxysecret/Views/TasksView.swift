import SwiftUI

struct TasksView: View {
    @State private var tasks: [ProjectTask] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var filter: TaskFilter = .all

    enum TaskFilter: String, CaseIterable, Identifiable {
        case all = "Todas"
        case pending = "Pendientes"
        case inProgress = "En curso"
        case done = "Hechas"
        var id: String { rawValue }

        var matches: (ProjectTask) -> Bool {
            switch self {
            case .all: return { _ in true }
            case .pending: return { $0.status == "pendiente" }
            case .inProgress: return { $0.status == "en_curso" }
            case .done: return { $0.status == "hecho" }
            }
        }
    }

    var filteredTasks: [ProjectTask] {
        tasks.filter(filter.matches)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(TaskFilter.allCases) { f in
                                Chip(text: f.rawValue, isSelected: filter == f) {
                                    filter = f
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                    }

                    if isLoading {
                        Spacer()
                        ProgressView().tint(Theme.gold)
                        Spacer()
                    } else if filteredTasks.isEmpty {
                        Spacer()
                        EmptyStateCard(
                            icon: "checklist",
                            title: "Sin tareas",
                            message: filter == .all ? "No tienes tareas aún" : "No hay tareas con ese filtro"
                        )
                        .padding(20)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(filteredTasks) { task in
                                    TaskRow(task: task)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                        .refreshable { await load() }
                    }
                }
            }
            .navigationTitle("Tareas")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Theme.bgPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            self.tasks = try await APIClient.shared.listTasks()
            self.error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct Chip: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .black : Theme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Theme.gold : Theme.bgCard)
                .clipShape(Capsule())
        }
    }
}

struct TaskRow: View {
    let task: ProjectTask

    var statusColor: Color {
        switch task.status {
        case "hecho": return Theme.success
        case "en_curso": return Theme.info
        case "pendiente": return Theme.warning
        default: return Theme.textTertiary
        }
    }

    var priorityColor: Color {
        switch task.priority {
        case "alta": return Theme.error
        case "media": return Theme.warning
        case "baja": return Theme.textTertiary
        default: return Theme.textTertiary
        }
    }

    var statusLabel: String {
        switch task.status {
        case "hecho": return "Hecha"
        case "en_curso": return "En curso"
        case "pendiente": return "Pendiente"
        default: return task.status
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(statusLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(statusColor)
                    Text("·")
                        .foregroundStyle(Theme.textTertiary)
                    Text(task.priority.capitalized)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(priorityColor)
                    if let owner = task.owner {
                        Text("·")
                            .foregroundStyle(Theme.textTertiary)
                        Text(owner.name)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            if let due = task.dueDate {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(due, format: .dateTime.day().month())
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(due, format: .dateTime.weekday())
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .padding(14)
        .background(Theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
