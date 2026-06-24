import SwiftUI

struct ClientDetailView: View {
    let client: Client
    let onChange: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var deleting = false
    @State private var projects: [Project] = []
    @State private var loadingProjects = true
    @State private var deleteError: String?

    var body: some View {
        ZStack {
            Theme.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    infoCard
                    projectsCard
                    if let err = deleteError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(Theme.error)
                            .padding(.horizontal)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(client.company ?? client.name)
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
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Theme.gold)
                }
            }
        }
        .sheet(isPresented: $showEdit, onDismiss: { Task { await reload() } }) {
            ClientEditView(mode: .edit(client), onSaved: {
                showEdit = false
            })
        }
        .confirmationDialog(
            "¿Eliminar a \(client.name)?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                Task { await deleteClient() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Solo se puede eliminar si no tiene proyectos o tareas asociadas.")
        }
        .task { await loadProjects() }
    }

    private var headerCard: some View {
        VStack(spacing: 14) {
            Circle()
                .fill(Theme.gold.opacity(0.2))
                .frame(width: 88, height: 88)
                .overlay(
                    Text(client.initials)
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(Theme.gold)
                )
            VStack(spacing: 4) {
                Text(client.name)
                    .font(.title2.bold())
                    .foregroundStyle(Theme.textPrimary)
                if let company = client.company, company != client.name {
                    Text(company)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(client.statusLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.15))
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Información")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            if let email = client.email, !email.isEmpty {
                InfoField(icon: "envelope", label: "Email", value: email)
            }
            if let phone = client.phone, !phone.isEmpty {
                InfoField(icon: "phone", label: "Teléfono", value: phone)
            }
            if let notes = client.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notas").font(.caption).foregroundStyle(Theme.textSecondary)
                    Text(notes).font(.callout).foregroundStyle(Theme.textPrimary)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var projectsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Proyectos")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                if !projects.isEmpty {
                    Text("\(projects.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            if loadingProjects {
                ProgressView().tint(Theme.gold)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if projects.isEmpty {
                Text("Este cliente aún no tiene proyectos.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(projects) { project in
                    NavigationLink {
                        ProjectDetailView(projectId: project.id)
                    } label: {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(Theme.gold)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(project.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text(project.statusLabel)
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(Theme.textTertiary)
                        }
                        .padding(12)
                        .background(Theme.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var statusColor: Color {
        switch client.status {
        case "activo": return Theme.success
        case "pausado": return Theme.warning
        case "baja": return Theme.error
        default: return Theme.textTertiary
        }
    }

    private func loadProjects() async {
        loadingProjects = true
        defer { loadingProjects = false }
        do {
            self.projects = try await APIClient.shared.listProjects(clientId: client.id)
        } catch {
            self.projects = []
        }
    }

    private func reload() async {
        onChange()
        await loadProjects()
    }

    private func deleteClient() async {
        deleting = true
        defer { deleting = false }
        do {
            try await APIClient.shared.deleteClient(id: client.id)
            onChange()
            dismiss()
        } catch {
            deleteError = error.localizedDescription
        }
    }
}

struct InfoField: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.gold)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(Theme.textSecondary)
                Text(value).font(.callout).foregroundStyle(Theme.textPrimary)
            }
            Spacer()
        }
    }
}
