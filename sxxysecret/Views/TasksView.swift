import SwiftUI

struct TasksView: View {
    @State private var tasks: [ProjectTask] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var filter: TaskFilter = .all
    @State private var showCreate = false

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
                                Chip(label: f.rawValue, isOn: filter == f) {
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
                                    NavigationLink {
                                        TaskDetailView(task: task) { Task { await load() } }
                                    } label: {
                                        TaskRow(task: task)
                                    }
                                    .buttonStyle(.plain)
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.gold)
                    }
                }
            }
            .sheet(isPresented: $showCreate) {
                TaskEditView(mode: .create) {
                    showCreate = false
                    Task { await load() }
                }
            }
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
    let label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isOn ? .black : Theme.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isOn ? Theme.gold : Theme.bgCard)
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
                    Text("·").foregroundStyle(Theme.textTertiary)
                    Text(task.priority.capitalized)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(priorityColor)
                    if let projectTitle = task.project?.title {
                        Text("·").foregroundStyle(Theme.textTertiary)
                        Text(projectTitle)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.gold)
                            .lineLimit(1)
                    }
                    if let owner = task.owner {
                        Text("·").foregroundStyle(Theme.textTertiary)
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

// MARK: - Task Detail
struct TaskDetailView: View {
    let task: ProjectTask
    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var deleteError: String?
    var onChange: () -> Void = {}

    var statusLabel: String {
        switch task.status {
        case "hecho": return "Hecha"
        case "en_curso": return "En curso"
        case "pendiente": return "Pendiente"
        default: return task.status
        }
    }

    var priorityLabel: String {
        task.priority.capitalized
    }

    var statusColor: Color {
        switch task.status {
        case "hecho": return Theme.success
        case "en_curso": return Theme.info
        case "pendiente": return Theme.warning
        default: return Theme.textTertiary
        }
    }

    var body: some View {
        ZStack {
            Theme.bgPrimary.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(task.title)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                        HStack(spacing: 8) {
                            Pill(text: statusLabel, color: statusColor)
                            Pill(text: priorityLabel, color: Theme.gold)
                            if let projectTitle = task.project?.title {
                                Pill(text: projectTitle, color: Theme.info)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    if let desc = task.description, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.horizontal, 20)
                    }

                    // Meta info
                    VStack(alignment: .leading, spacing: 10) {
                        if let owner = task.owner {
                            MetaRow(icon: "person.fill", label: "Owner", value: owner.name)
                        }
                        if let assignee = task.assignee {
                            MetaRow(icon: "person.crop.circle.badge.checkmark", label: "Asignado", value: assignee.name)
                        }
                        if let due = task.dueDate {
                            MetaRow(icon: "calendar", label: "Vence", value: due.formatted(date: .abbreviated, time: .omitted))
                        }
                    }
                    .padding(.horizontal, 20)

                    // Attachments
                    let imgs = task.images ?? []
                    let vids = task.videos ?? []
                    let docs = task.documents ?? []
                    if !imgs.isEmpty || !vids.isEmpty || !docs.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Archivos")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                                .padding(.horizontal, 20)

                            if !imgs.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(imgs) { img in
                                            VStack(alignment: .leading, spacing: 4) {
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(Theme.bgCard)
                                                        .frame(width: 110, height: 110)
                                                    Image(systemName: "photo")
                                                        .font(.system(size: 28))
                                                        .foregroundStyle(Theme.textSecondary)
                                                }
                                                Text(img.filename)
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(Theme.textSecondary)
                                                    .lineLimit(1)
                                                    .frame(width: 110, alignment: .leading)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            if !docs.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(docs) { d in
                                        HStack(spacing: 8) {
                                            Image(systemName: "doc.fill")
                                                .foregroundStyle(Theme.info)
                                            Text(d.filename)
                                                .font(.system(size: 13))
                                                .foregroundStyle(Theme.textPrimary)
                                                .lineLimit(1)
                                            Spacer()
                                            if let s = d.size {
                                                Text(formatBytes(s))
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(Theme.textTertiary)
                                            }
                                        }
                                        .padding(10)
                                        .background(Theme.bgCard)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }

                    if let err = deleteError {
                        Text(err).font(.caption).foregroundStyle(Theme.error)
                            .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationTitle("Detalle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.bgPrimary, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showEdit = true } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundStyle(Theme.gold)
                }
            }
        }
        .sheet(isPresented: $showEdit, onDismiss: { onChange() }) {
            TaskEditView(mode: .edit(task)) { showEdit = false }
        }
        .confirmationDialog(
            "¿Eliminar esta tarea?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) { Task { await deleteTask() } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }

    private func formatBytes(_ b: Int) -> String {
        if b < 1024 { return "\(b) B" }
        if b < 1024 * 1024 { return "\(b / 1024) KB" }
        return "\(b / (1024*1024)) MB"
    }

    private func deleteTask() async {
        do {
            try await APIClient.shared.deleteTask(id: task.id)
            onChange()
            dismiss()
        } catch {
            deleteError = error.localizedDescription
        }
    }
}

struct Pill: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
            .textCase(.uppercase)
    }
}

struct MetaRow: View {
    let icon: String
    let label: String
    let value: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Theme.gold)
                .frame(width: 28, height: 28)
                .background(Theme.gold.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .textCase(.uppercase)
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
        }
        .padding(12)
        .background(Theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
