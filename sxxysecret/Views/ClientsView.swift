import SwiftUI

struct ClientsView: View {
    @State private var clients: [Client] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(Theme.gold)
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
                        Button("Reintentar") {
                            Task { await load() }
                        }
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
                            ForEach(clients) { client in
                                ClientCard(client: client)
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
        case "inactivo": return Theme.textTertiary
        case "prospecto": return Theme.warning
        default: return Theme.textTertiary
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
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
