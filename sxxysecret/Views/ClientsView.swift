import SwiftUI

struct ClientsView: View {
    @State private var clients: [Client] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var query: String = ""
    @State private var showCreate = false

    var filtered: [Client] {
        guard !query.isEmpty else { return clients }
        let q = query.lowercased()
        return clients.filter {
            ($0.name).lowercased().contains(q) ||
            ($0.company ?? "").lowercased().contains(q) ||
            ($0.email ?? "").lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()

                if isLoading {
                    ProgressView().tint(Theme.gold)
                } else if let error = error {
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundStyle(Theme.error)
                        Text("Error al cargar")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                        Button("Reintentar") { Task { await load() } }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.gold)
                    }
                    .padding()
                } else if clients.isEmpty {
                    EmptyStateCard(
                        icon: "person.2.badge.plus",
                        title: "Sin clientes",
                        message: "Aquí aparecerán tus clientes cuando los agregues"
                    )
                    .padding(20)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filtered) { client in
                                NavigationLink {
                                    ClientDetailView(client: client, onChange: { Task { await load() } })
                                } label: {
                                    ClientCard(client: client)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(20)
                    }
                    .refreshable { await load() }
                }
            }
            .navigationTitle("Clientes")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Theme.bgPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .searchable(text: $query, prompt: "Buscar cliente, empresa o email")
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
                ClientEditView(mode: .create, onSaved: {
                    showCreate = false
                    Task { await load() }
                })
            }
        }
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            self.clients = try await APIClient.shared.listClients()
            self.error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct ClientCard: View {
    let client: Client

    var statusColor: Color {
        switch client.status {
        case "activo": return Theme.success
        case "pausado": return Theme.warning
        case "baja": return Theme.error
        default: return Theme.textTertiary
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(Theme.gold.opacity(0.2))
                .frame(width: 52, height: 52)
                .overlay(
                    Text(client.initials)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(Theme.gold)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(client.company ?? client.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                if let email = client.email {
                    Text(email)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Circle().fill(statusColor).frame(width: 6, height: 6)
                    Text(client.statusLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(statusColor)
                }
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
