import SwiftUI

/// Reusable form for both creating a new project and editing an existing one.
/// Lets admins/managers pick the client, status, progress, budget, dates, and
/// manage members (add/remove with per-member role).
///
/// Backend contract:
/// - `clientId` (not `client`) is the field name for the client reference.
/// - Members are added by EMAIL (backend resolves to user). Backend doesn't
///   accept members inline on create — we POST a separate request per member.
struct ProjectEditView: View {
    enum Mode {
        case create
        case edit(Project)
    }

    let mode: Mode
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var clientId: String? = nil
    @State private var clientName: String = ""
    @State private var status: String = "activo"
    @State private var progress: Double = 0
    @State private var budgetText: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(60*60*24*30)
    @State private var hasStartDate: Bool = false
    @State private var hasEndDate: Bool = false
    @State private var hasBudget: Bool = false

    /// Local member list — email + role. Backend resolves user from email.
    /// Cached userId is used for removal diff on edit.
    struct MemberEntry: Identifiable, Hashable {
        let email: String
        let name: String
        let userId: String  // "" if newly added in this session
        var role: ProjectMemberRole
        var id: String { email }
    }
    @State private var members: [MemberEntry] = []

    @State private var clients: [Client] = []
    @State private var users: [User] = []
    @State private var loadingLookups = true
    @State private var showClientPicker = false
    @State private var showAddMember = false

    @State private var saving = false
    @State private var error: String?

    private let statuses = ["activo", "pausado", "completado"]

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
                        labeledField("Título *", text: $title)
                        HStack {
                            Text("Cliente *").foregroundStyle(Theme.textPrimary)
                                .frame(width: 80, alignment: .leading)
                            Button {
                                showClientPicker = true
                            } label: {
                                HStack {
                                    Text(clientName.isEmpty ? "Seleccionar…" : clientName)
                                        .foregroundStyle(clientName.isEmpty ? Theme.textTertiary : Theme.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(Theme.textTertiary)
                                }
                            }
                        }
                        TextField("Descripción", text: $description, axis: .vertical)
                            .lineLimit(2...4)
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .listRowBackground(Theme.bgCard)

                    Section("Estado y avance") {
                        Picker("Estado", selection: $status) {
                            ForEach(statuses, id: \.self) { s in
                                Text(s.capitalized).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Progreso").foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text("\(Int(progress))%")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Theme.gold)
                            }
                            Slider(value: $progress, in: 0...100, step: 5)
                                .tint(Theme.gold)
                        }
                    }
                    .listRowBackground(Theme.bgCard)

                    Section("Presupuesto y fechas") {
                        Toggle("Tiene presupuesto", isOn: $hasBudget)
                        if hasBudget {
                            HStack {
                                Text("$").foregroundStyle(Theme.textSecondary)
                                TextField("0.00", text: $budgetText)
                                    .keyboardType(.decimalPad)
                                    .foregroundStyle(Theme.textPrimary)
                            }
                        }
                        Toggle("Fecha de inicio", isOn: $hasStartDate)
                        if hasStartDate {
                            DatePicker("", selection: $startDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                        Toggle("Fecha de fin", isOn: $hasEndDate)
                        if hasEndDate {
                            DatePicker("", selection: $endDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                    }
                    .listRowBackground(Theme.bgCard)

                    Section {
                        ForEach(members) { m in
                            MemberRowEditable(member: m) { newRole in
                                if let idx = members.firstIndex(where: { $0.id == m.id }) {
                                    members[idx].role = newRole
                                }
                            } onRemove: {
                                members.removeAll { $0.id == m.id }
                            }
                        }
                        Button {
                            showAddMember = true
                        } label: {
                            Label("Agregar miembro", systemImage: "person.badge.plus")
                                .foregroundStyle(Theme.gold)
                        }
                    } header: {
                        Text("Equipo")
                    } footer: {
                        Text("Toca el rol de cada miembro para cambiarlo.")
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
                                    Text(isEdit ? "Guardar cambios" : "Crear proyecto")
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
            .navigationTitle(isEdit ? "Editar proyecto" : "Nuevo proyecto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bgPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.foregroundStyle(Theme.gold)
                }
            }
            .sheet(isPresented: $showClientPicker) {
                ClientPickerSheet(clients: clients) { c in
                    clientId = c.id
                    clientName = c.company ?? c.name
                    showClientPicker = false
                }
            }
            .sheet(isPresented: $showAddMember) {
                AddMemberSheet(users: users, alreadyAddedEmails: members.map { $0.email }) { newMember in
                    if !members.contains(where: { $0.id == newMember.id }) {
                        members.append(newMember)
                    }
                    showAddMember = false
                }
            }
            .task { await loadLookups() }
            .onAppear(perform: prefill)
        }
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && clientId != nil
    }

    @ViewBuilder
    private func labeledField(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.textPrimary)
                .frame(width: 90, alignment: .leading)
            TextField(label, text: text)
                .foregroundStyle(Theme.textPrimary)
        }
    }

    private func loadLookups() async {
        loadingLookups = true
        defer { loadingLookups = false }
        async let c = APIClient.shared.listClients()
        async let u = APIClient.shared.listUsers()
        do {
            let (cs, us) = try await (c, u)
            self.clients = cs
            self.users = us
        } catch {
            self.error = "Error al cargar datos: \(error.localizedDescription)"
        }
    }

    private func prefill() {
        if case .edit(let p) = mode {
            title = p.title
            description = p.description ?? ""
            clientId = p.client?.id
            clientName = p.client?.company ?? p.client?.name ?? ""
            status = p.status
            progress = Double(p.progress)
            if let b = p.budget {
                hasBudget = true
                budgetText = String(Int(b))
            }
            if let s = p.startDate {
                hasStartDate = true
                startDate = s
            }
            if let e = p.endDate {
                hasEndDate = true
                endDate = e
            }
            members = (p.members ?? []).compactMap { m in
                guard let role = ProjectMemberRole(rawValue: m.role),
                      let email = m.user.email else { return nil }
                return MemberEntry(email: email, name: m.user.name, userId: m.user.id, role: role)
            }
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        let t = title.trimmingCharacters(in: .whitespaces)
        let desc = description.trimmingCharacters(in: .whitespaces)
        let budget: Double? = hasBudget ? Double(budgetText.replacingOccurrences(of: ",", with: ".")) : nil
        let sd: Date? = hasStartDate ? startDate : nil
        let ed: Date? = hasEndDate ? endDate : nil
        do {
            switch mode {
            case .create:
                guard let cid = clientId else { error = "Selecciona un cliente"; return }
                let created = try await APIClient.shared.createProject(
                    title: t, description: desc.isEmpty ? nil : desc, clientId: cid,
                    status: status, progress: Int(progress),
                    budget: budget, startDate: sd, endDate: ed,
                    memberEmails: [:]
                )
                // Backend doesn't accept inline members on create — add them after.
                for m in members {
                    _ = try? await APIClient.shared.addProjectMember(
                        projectId: created.id, email: m.email, role: m.role.rawValue
                    )
                }
            case .edit(let p):
                _ = try await APIClient.shared.updateProject(
                    id: p.id, title: t, description: desc, clientId: clientId,
                    status: status, progress: Int(progress),
                    budget: budget, startDate: sd, endDate: ed
                )
                // Diff members: emails present now vs original
                let originalEmails = Set((p.members ?? []).compactMap { $0.user.email })
                let currentEmails = Set(members.map { $0.email })
                let toAdd = currentEmails.subtracting(originalEmails)
                let toRemoveIds = (p.members ?? [])
                    .filter { originalEmails.contains($0.user.email ?? "") && !currentEmails.contains($0.user.email ?? "") }
                    .map { $0.user.id }
                for m in members where toAdd.contains(m.email) {
                    try await APIClient.shared.addProjectMember(
                        projectId: p.id, email: m.email, role: m.role.rawValue
                    )
                }
                for uid in toRemoveIds {
                    try await APIClient.shared.removeProjectMember(projectId: p.id, userId: uid)
                }
            }
            onSaved()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Editable member row
private struct MemberRowEditable: View {
    let member: ProjectEditView.MemberEntry
    let onRoleChange: (ProjectMemberRole) -> Void
    let onRemove: () -> Void

    var initials: String {
        let parts = member.name.split(separator: " ")
        let f = parts.first?.first.map(String.init) ?? ""
        let l = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (f + l).uppercased()
    }

    var body: some View {
        HStack {
            Circle()
                .fill(Theme.gold.opacity(0.2))
                .frame(width: 36, height: 36)
                .overlay(
                    Text(initials)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.gold)
                )
            VStack(alignment: .leading) {
                Text(member.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(member.email)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Menu {
                ForEach(ProjectMemberRole.allCases) { r in
                    Button {
                        onRoleChange(r)
                    } label: {
                        HStack {
                            Text(r.label)
                            if member.role == r {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Text(member.role.label)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(member.role.color.opacity(0.2))
                    .foregroundStyle(member.role.color)
                    .clipShape(Capsule())
            }
            Button(role: .destructive, action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(Theme.error)
            }
        }
    }
}

// MARK: - Client picker sheet
private struct ClientPickerSheet: View {
    let clients: [Client]
    let onSelect: (Client) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var q = ""

    var filtered: [Client] {
        guard !q.isEmpty else { return clients }
        let s = q.lowercased()
        return clients.filter {
            $0.name.lowercased().contains(s) || ($0.company ?? "").lowercased().contains(s)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()
                List {
                    ForEach(filtered) { c in
                        Button {
                            onSelect(c)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(Theme.gold.opacity(0.2))
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Text(c.initials)
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(Theme.gold)
                                    )
                                VStack(alignment: .leading) {
                                    Text(c.company ?? c.name).font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Theme.textPrimary)
                                    if let email = c.email, !email.isEmpty {
                                        Text(email).font(.caption).foregroundStyle(Theme.textSecondary)
                                    }
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
            .navigationTitle("Selecciona cliente")
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

// MARK: - Add-member sheet
private struct AddMemberSheet: View {
    let users: [User]
    let alreadyAddedEmails: [String]
    let onAdd: (ProjectEditView.MemberEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var q = ""
    @State private var selectedRole: ProjectMemberRole = .colaborador

    var filtered: [User] {
        let pool = users.filter { !alreadyAddedEmails.contains($0.email) }
        guard !q.isEmpty else { return pool }
        let s = q.lowercased()
        return pool.filter {
            $0.name.lowercased().contains(s) || $0.email.lowercased().contains(s)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()
                VStack(spacing: 0) {
                    Picker("Rol inicial", selection: $selectedRole) {
                        ForEach(ProjectMemberRole.allCases) { r in
                            Text(r.label).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    if filtered.isEmpty {
                        EmptyStateCard(
                            icon: "person.fill.questionmark",
                            title: "Sin usuarios",
                            message: "Todos los usuarios ya están agregados."
                        )
                        .padding(20)
                    } else {
                        List {
                            ForEach(filtered) { u in
                                Button {
                                    onAdd(.init(email: u.email, name: u.name, userId: u.id, role: selectedRole))
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
                                        Image(systemName: "plus.circle")
                                            .foregroundStyle(Theme.gold)
                                    }
                                }
                                .listRowBackground(Theme.bgCard)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Agregar miembro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bgPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(text: $q, prompt: "Buscar usuario")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }.foregroundStyle(Theme.gold)
                }
            }
        }
    }
}
