import SwiftUI

/// Admin-only screen: list users, search, create, edit, delete.
/// Non-admins see a friendly access-denied card.
struct UsersView: View {
    @State private var users: [User] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var query: String = ""
    @State private var roleFilter: String? = nil
    @State private var showCreate = false
    @State private var me: User? = AuthService.shared.user

    private let roles = ["admin", "manager", "member", "client"]

    var filtered: [User] {
        users.filter { u in
            let q = query.lowercased()
            let matchesQ = q.isEmpty ||
                u.name.lowercased().contains(q) ||
                u.email.lowercased().contains(q)
            let matchesRole = roleFilter == nil || u.role == roleFilter
            return matchesQ && matchesRole
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()

                if let me = me, me.role != "admin" {
                    EmptyStateCard(
                        icon: "lock.fill",
                        title: "Acceso restringido",
                        message: "Solo administradores pueden ver y gestionar usuarios."
                    )
                    .padding(20)
                } else if isLoading {
                    ProgressView().tint(Theme.gold)
                } else if let error = error {
                    errorView(error)
                } else if users.isEmpty {
                    EmptyStateCard(
                        icon: "person.3.fill",
                        title: "Sin usuarios",
                        message: "Aquí aparecerán los miembros del equipo"
                    )
                    .padding(20)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            roleChips
                            ForEach(filtered) { user in
                                NavigationLink {
                                    UserDetailView(user: user, onChange: { Task { await load() } })
                                } label: {
                                    UserCard(user: user)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(20)
                    }
                    .refreshable { await load() }
                }
            }
            .navigationTitle("Usuarios")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Theme.bgPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(text: $query, prompt: "Buscar por nombre o email")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if me?.role == "admin" {
                        Button {
                            showCreate = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Theme.gold)
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreate) {
                UserEditView(mode: .create, onSaved: {
                    showCreate = false
                    Task { await load() }
                })
            }
        }
        .task { await load() }
    }

    private var roleChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(label: "Todos", isOn: roleFilter == nil) {
                    roleFilter = nil
                }
                ForEach(roles, id: \.self) { r in
                    Chip(label: roleLabel(r), isOn: roleFilter == r) {
                        roleFilter = (roleFilter == r) ? nil : r
                    }
                }
            }
            .padding(.bottom, 4)
        }
    }

    private func roleLabel(_ r: String) -> String {
        switch r {
        case "admin": return "Admins"
        case "manager": return "Managers"
        case "member": return "Miembros"
        case "client": return "Clientes"
        default: return r.capitalized
        }
    }

    @ViewBuilder
    private func errorView(_ err: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(Theme.error)
            Text("Error al cargar").font(.headline).foregroundStyle(Theme.textPrimary)
            Text(err).font(.caption).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
            Button("Reintentar") { Task { await load() } }
                .buttonStyle(.borderedProminent)
                .tint(Theme.gold)
        }
        .padding()
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            self.users = try await APIClient.shared.listUsers()
            self.error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct UserCard: View {
    let user: User

    var roleColor: Color {
        switch user.role {
        case "admin": return Theme.accent
        case "manager": return Theme.info
        case "member": return Theme.gold
        case "client": return Theme.success
        default: return Theme.textSecondary
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(roleColor.opacity(0.2))
                .frame(width: 52, height: 52)
                .overlay(
                    Text(user.initials)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(roleColor)
                )
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(user.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    if user.active == false {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                Text(user.email)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                Text(user.roleLabel)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(roleColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(roleColor.opacity(0.15))
                    .clipShape(Capsule())
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Theme.textTertiary)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(16)
        .background(Theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

