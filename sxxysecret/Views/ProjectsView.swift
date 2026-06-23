import SwiftUI

struct ProjectsView: View {
    @State private var projects: [Project] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()

                if isLoading {
                    ProgressView().tint(Theme.gold)
                } else if projects.isEmpty {
                    EmptyStateCard(
                        icon: "folder.badge.plus",
                        title: "Sin proyectos",
                        message: "Crea tu primer proyecto desde un cliente"
                    )
                    .padding(20)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(projects) { project in
                                NavigationLink {
                                    ProjectDetailView(project: project)
                                } label: {
                                    ProjectCard(project: project)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(20)
                    }
                    .refreshable { await load() }
                }
            }
            .navigationTitle("Proyectos")
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
            self.projects = try await APIClient.shared.dashboardProjects()
        } catch {}
    }
}
