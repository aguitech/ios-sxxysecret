import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var auth: AuthService
    @State private var stats: DashboardStats?
    @State private var projects: [Project] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hola, \(auth.user?.name.components(separatedBy: " ").first ?? "") 👋")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundStyle(Theme.textPrimary)
                            Text("Aquí está el resumen de hoy")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                        // Stats grid
                        if let stats = stats {
                            StatsGrid(stats: stats)
                                .padding(.horizontal, 20)
                        }

                        // Proyectos recientes
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Proyectos")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text("\(projects.count)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.gold)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Theme.gold.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            .padding(.horizontal, 20)

                            if isLoading {
                                ForEach(0..<3, id: \.self) { _ in
                                    ProjectCardSkeleton()
                                        .padding(.horizontal, 20)
                                }
                            } else if projects.isEmpty {
                                EmptyStateCard(
                                    icon: "folder.badge.questionmark",
                                    title: "Sin proyectos",
                                    message: "Crea tu primer proyecto desde la sección de Clientes"
                                )
                                .padding(.horizontal, 20)
                            } else {
                                ForEach(projects.prefix(5)) { project in
                                    NavigationLink {
                                        ProjectDetailView(projectId: project.id)
                                    } label: {
                                        ProjectCard(project: project)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal, 20)
                                }
                            }
                        }

                        Spacer(minLength: 40)
                    }
                }
                .refreshable { await loadData() }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bgPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task { await loadData() }
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        async let s: () = loadStats()
        async let p: () = loadProjects()
        _ = await (s, p)
    }

    private func loadStats() async {
        do {
            self.stats = try await APIClient.shared.dashboardStats()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func loadProjects() async {
        do {
            self.projects = try await APIClient.shared.dashboardProjects()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct StatsGrid: View {
    let stats: DashboardStats

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                StatCard(title: "Total", value: "\(stats.total)", icon: "folder.fill", color: Theme.info)
                StatCard(title: "Activos", value: "\(stats.activos)", icon: "bolt.fill", color: Theme.success)
            }
            HStack(spacing: 12) {
                StatCard(title: "Completados", value: "\(stats.completados)", icon: "checkmark.seal.fill", color: Theme.gold)
                StatCard(title: "Progreso", value: "\(stats.promedio)%", icon: "chart.line.uptrend.xyaxis", color: Theme.accent)
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Spacer()
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ProjectCard: View {
    let project: Project

    var statusColor: Color {
        switch project.status {
        case "activo": return Theme.success
        case "completado": return Theme.info
        case "pausado": return Theme.warning
        case "cancelado": return Theme.error
        default: return Theme.textTertiary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(project.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text(project.statusLabel)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.15))
                    .clipShape(Capsule())
                    .textCase(.uppercase)
            }

            if let client = project.client {
                HStack(spacing: 6) {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 11))
                    Text(client.company ?? client.name)
                        .font(.system(size: 13))
                }
                .foregroundStyle(Theme.textSecondary)
            }

            // Progress bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Progreso")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                    Spacer()
                    Text("\(project.progress)%")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.gold)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.bgSecondary)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.gold)
                            .frame(width: geo.size.width * CGFloat(project.progress) / 100)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(16)
        .background(Theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ProjectCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 4).fill(Theme.bgSecondary).frame(height: 18)
            RoundedRectangle(cornerRadius: 4).fill(Theme.bgSecondary).frame(height: 12)
            RoundedRectangle(cornerRadius: 4).fill(Theme.bgSecondary).frame(height: 6)
        }
        .padding(16)
        .background(Theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(Theme.textTertiary)
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(Theme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
