import SwiftUI

struct UserDetailView: View {
    let user: User
    let onChange: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var deleteError: String?

    var body: some View {
        ZStack {
            Theme.bgPrimary.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    infoCard
                    if let err = deleteError {
                        Text(err).font(.caption).foregroundStyle(Theme.error)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(user.name)
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
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Theme.gold)
                }
            }
        }
        .sheet(isPresented: $showEdit, onDismiss: { Task { onChange() } }) {
            UserEditView(mode: .edit(user), onSaved: { showEdit = false })
        }
        .confirmationDialog(
            "¿Eliminar a \(user.name)?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                Task { await deleteUser() }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }

    private var headerCard: some View {
        VStack(spacing: 14) {
            Circle()
                .fill(roleColor.opacity(0.2))
                .frame(width: 88, height: 88)
                .overlay(
                    Text(user.initials)
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(roleColor)
                )
            VStack(spacing: 4) {
                Text(user.name).font(.title2.bold()).foregroundStyle(Theme.textPrimary)
                Text(user.email).font(.subheadline).foregroundStyle(Theme.textSecondary)
            }
            Text(user.roleLabel)
                .font(.caption.weight(.bold))
                .foregroundStyle(roleColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(roleColor.opacity(0.15))
                .clipShape(Capsule())
            if let active = user.active, !active {
                Text("Usuario desactivado")
                    .font(.caption)
                    .foregroundStyle(Theme.warning)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Información").font(.headline).foregroundStyle(Theme.textPrimary)
            if let phone = user.phone, !phone.isEmpty {
                InfoField(icon: "phone", label: "Teléfono", value: phone)
            }
            if let lastLogin = user.lastLogin {
                InfoField(icon: "clock", label: "Último login", value: lastLogin.formatted(date: .abbreviated, time: .shortened))
            }
            if let created = user.createdAt {
                InfoField(icon: "calendar", label: "Miembro desde", value: created.formatted(date: .abbreviated, time: .omitted))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var roleColor: Color {
        switch user.role {
        case "admin": return Theme.accent
        case "manager": return Theme.info
        case "member": return Theme.gold
        case "client": return Theme.success
        default: return Theme.textSecondary
        }
    }

    private func deleteUser() async {
        do {
            try await APIClient.shared.deleteUser(id: user.id)
            onChange()
            dismiss()
        } catch {
            deleteError = error.localizedDescription
        }
    }
}
