import SwiftUI

/// Reusable form for creating or editing a task.
/// Pickers for project (loads on appear), assignee, status, priority, dueDate.
struct TaskEditView: View {
    enum Mode {
        case create
        case edit(ProjectTask)
    }

    let mode: Mode
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var status: String = "pendiente"
    @State private var priority: String = "media"
    @State private var projectId: String? = nil
    @State private var projectTitle: String = ""
    @State private var assigneeId: String? = nil
    @State private var assigneeName: String = ""
    @State private var dueDate: Date = Date().addingTimeInterval(60*60*24*7)
    @State private var hasDueDate: Bool = false

    @State private var projects: [Project] = []
    @State private var users: [User] = []
    @State private var loadingLookups = true
    @State private var showProjectPicker = false
    @State private var showAssigneePicker = false

    @State private var saving = false
    @State private var error: String?

    private let statuses = ["pendiente", "en_curso", "hecho"]
    private let priorities = ["baja", "media", "alta"]

    private var isEdit: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()
                Form {
                    Section("Datos básicos") {
                        HStack {
                            Text("Título *").foregroundStyle(Theme.textPrimary)
                                .frame(width: 80, alignment: .leading)
                            TextField("Título de la tarea", text: $title)
                                .foregroundStyle(Theme.textPrimary)
                        }
                        TextField("Descripción", text: $description, axis: .vertical)
                            .lineLimit(2...5)
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .listRowBackground(Theme.bgCard)

                    Section("Estado y prioridad") {
                        Picker("Estado", selection: $status) {
                            ForEach(statuses, id: \.self) { s in
                                Text(statusLabel(s)).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)
                        Picker("Prioridad", selection: $priority) {
                            ForEach(priorities, id: \.self) { p in
                                Text(priorityLabel(p)).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .listRowBackground(Theme.bgCard)

                    Section("Asignación") {
                        HStack {
                            Text("Proyecto").foregroundStyle(Theme.textPrimary)
                                .frame(width: 90, alignment: .leading)
                            Button {
                                showProjectPicker = true
                            } label: {
                                HStack {
                                    Text(projectTitle.isEmpty ? "Sin proyecto" : projectTitle)
                                        .foregroundStyle(projectTitle.isEmpty ? Theme.textTertiary : Theme.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(Theme.textTertiary)
                                }
                            }
                        }
                        HStack {
                            Text("Asignado a").foregroundStyle(Theme.textPrimary)
                                .frame(width: 90, alignment: .leading)
                            Button {
                                showAssigneePicker = true
                            } label: {
                                HStack {
                                    Text(assigneeName.isEmpty ? "Sin asignar" : assigneeName)
                                        .foregroundStyle(assigneeName.isEmpty ? Theme.textTertiary : Theme.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(Theme.textTertiary)
                                }
                            }
                        }
                    }
                    .listRowBackground(Theme.bgCard)

                    Section("Fecha límite") {
                        Toggle("Tiene fecha", isOn: $hasDueDate)
                        if hasDueDate {
                            DatePicker("", selection: $dueDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                    }
                    .listRowBackground(Theme.bgCard)

                    if let err = error {
                        Section {
                            Text(err).font(.caption).foregroundStyle(Theme.error)
                        }
                    }

                    Section {
                        Button {
                            Task { await save() }
                        } label: {
                            HStack {
                                Spacer()
                                if saving {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(isEdit ? "Guardar cambios" : "Crear tarea")
                                        .font(.headline)
                                }
                                Spacer()
                            }
                            .foregroundStyle(.white)
                            .padding(.vertical, 6)
                        }
                        .listRowBackground(Theme.gold)
                        .disabled(!isValid || saving)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(isEdit ? "Editar tarea" : "Nueva tarea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bgPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.foregroundStyle(Theme.gold)
                }
            }
            .sheet(isPresented: $showProjectPicker) {
                ProjectPickerSheet(projects: projects) { p in
                    projectId = p.id
                    projectTitle = p.title
                    showProjectPicker = false
                }
            }
            .sheet(isPresented: $showAssigneePicker) {
                AssigneePickerSheet(users: users, currentAssigneeId: assigneeId) { u in
                    assigneeId = u.id
                    assigneeName = u.name
                    showAssigneePicker = false
                } onClear: {
                    assigneeId = nil
                    assigneeName = ""
                    showAssigneePicker = false
                }
            }
            .task { await loadLookups() }
            .onAppear(perform: prefill)
        }
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func statusLabel(_ s: String) -> String {
        switch s {
        case "pendiente": return "Pendiente"
        case "en_curso": return "En curso"
        case "hecho": return "Hecho"
        default: return s
        }
    }

    private func priorityLabel(_ p: String) -> String {
        switch p {
        case "baja": return "Baja"
        case "media": return "Media"
        case "alta": return "Alta"
        default: return p
        }
    }

    private func loadLookups() async {
        loadingLookups = true
        defer { loadingLookups = false }
        async let p = APIClient.shared.listProjects()
        async let u = APIClient.shared.listUsers()
        do {
            let (ps, us) = try await (p, u)
            self.projects = ps
            self.users = us
        } catch {
            self.error = "Error al cargar datos: \(error.localizedDescription)"
        }
    }

    private func prefill() {
        if case .edit(let t) = mode {
            title = t.title
            description = t.description ?? ""
            status = t.status
            priority = t.priority
            if let pid = t.project?.id {
                projectId = pid
                projectTitle = t.project?.title ?? ""
            }
            if let a = t.assignee {
                assigneeId = a.id
                assigneeName = a.name
            }
            if let d = t.dueDate {
                hasDueDate = true
                dueDate = d
            }
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        let t = title.trimmingCharacters(in: .whitespaces)
        let desc = description.trimmingCharacters(in: .whitespaces)
        let dd: Date? = hasDueDate ? dueDate : nil
        do {
            switch mode {
            case .create:
                _ = try await APIClient.shared.createTask(
                    title: t,
                    description: desc.isEmpty ? nil : desc,
                    status: status,
                    priority: priority,
                    projectId: projectId,
                    clientId: nil,
                    assigneeId: assigneeId,
                    dueDate: dd
                )
            case .edit(let tk):
                _ = try await APIClient.shared.updateTask(
                    id: tk.id,
                    title: t,
                    description: desc,
                    status: status,
                    priority: priority,
                    projectId: projectId,
                    assigneeId: assigneeId,
                    dueDate: dd
                )
            }
            onSaved()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Project picker sheet
private struct ProjectPickerSheet: View {
    let projects: [Project]
    let onSelect: (Project) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var q = ""

    var filtered: [Project] {
        guard !q.isEmpty else { return projects }
        let s = q.lowercased()
        return projects.filter { $0.title.lowercased().contains(s) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()
                List {
                    Button {
                        onSelect(Project(
                            id: "",
                            title: "",
                            status: "activo",
                            progress: 0,
                            description: nil,
                            budget: nil,
                            startDate: nil,
                            endDate: nil,
                            owner: nil,
                            client: nil,
                            members: nil,
                            createdAt: nil,
                            updatedAt: nil
                        ))
                    } label: {
                        Label("Sin proyecto", systemImage: "xmark.circle")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .listRowBackground(Theme.bgCard)
                    ForEach(filtered) { p in
                        Button {
                            onSelect(p)
                        } label: {
                            HStack {
                                Image(systemName: "folder.fill").foregroundStyle(Theme.gold)
                                VStack(alignment: .leading) {
                                    Text(p.title).font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text(p.statusLabel).font(.caption).foregroundStyle(Theme.textSecondary)
                                }
                                Spacer()
                            }
                        }
                        .listRowBackground(Theme.bgCard)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Proyecto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bgPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(text: $q, prompt: "Buscar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }.foregroundStyle(Theme.gold)
                }
            }
        }
    }
}

// MARK: - Assignee picker sheet
private struct AssigneePickerSheet: View {
    let users: [User]
    let currentAssigneeId: String?
    let onSelect: (User) -> Void
    let onClear: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var q = ""

    var filtered: [User] {
        guard !q.isEmpty else { return users }
        let s = q.lowercased()
        return users.filter {
            $0.name.lowercased().contains(s) || $0.email.lowercased().contains(s)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()
                List {
                    Button {
                        onClear()
                    } label: {
                        Label("Sin asignar", systemImage: "person.slash")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .listRowBackground(Theme.bgCard)
                    ForEach(filtered) { u in
                        Button {
                            onSelect(u)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(Theme.gold.opacity(0.2))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Text(u.initials)
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Theme.gold)
                                    )
                                VStack(alignment: .leading) {
                                    Text(u.name).font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                    Text(u.email).font(.caption).foregroundStyle(Theme.textSecondary)
                                }
                                Spacer()
                                if u.id == currentAssigneeId {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.gold)
                                }
                            }
                        }
                        .listRowBackground(Theme.bgCard)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Asignar a")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bgPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(text: $q, prompt: "Buscar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }.foregroundStyle(Theme.gold)
                }
            }
        }
    }
}
