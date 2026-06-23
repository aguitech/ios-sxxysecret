import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    @State private var detail: ProjectDetail?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Theme.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text(project.title)
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)

                        if let desc = project.description, !desc.isEmpty {
                            Text(desc)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textSecondary)
                        }

                        if let client = project.client {
                            HStack(spacing: 6) {
                                Image(systemName: "building.2.fill")
                                    .foregroundStyle(Theme.gold)
                                Text(client.company ?? client.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                            }
                        }
                    }
                    .padding(20)

                    if let detail = detail {
                        // Stats
                        HStack(spacing: 12) {
                            StatCard(title: "Tareas", value: "\(detail.stats.totalTasks)", icon: "checklist", color: Theme.info)
                            StatCard(title: "Progreso", value: "\(detail.stats.weightedProgress)%", icon: "chart.line.uptrend.xyaxis", color: Theme.gold)
                        }
                        .padding(.horizontal, 20)

                        HStack(spacing: 12) {
                            StatCard(title: "Vencidas", value: "\(detail.stats.overdue)", icon: "exclamationmark.triangle.fill", color: Theme.error)
                            StatCard(title: "Miembros", value: "\(detail.stats.membersCount)", icon: "person.2.fill", color: Theme.accent)
                        }
                        .padding(.horizontal, 20)

                        // Tareas
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tareas")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                                .padding(.horizontal, 20)

                            if detail.tasks.isEmpty {
                                Text("Sin tareas asignadas")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(20)
                                    .background(Theme.bgCard)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .padding(.horizontal, 20)
                            } else {
                                ForEach(detail.tasks.prefix(10)) { task in
                                    TaskRow(task: task)
                                        .padding(.horizontal, 20)
                                }
                            }
                        }
                    } else if isLoading {
                        ProgressView().tint(Theme.gold).padding(40)
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
        .task {
            do {
                self.detail = try await APIClient.shared.projectDetail(id: project.id)
            } catch {}
            isLoading = false
        }
    }
}
