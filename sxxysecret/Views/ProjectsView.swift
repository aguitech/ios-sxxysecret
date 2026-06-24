import SwiftUI

struct ProjectsView: View {
    @State private var projects: [Project] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var query: String = ""
    @State private var statusFilter: String? = nil
    @State private var showCreate = false

    private let statuses = ["activo", "pausado", "completado"]

    var filtered: [Project] {
        projects.filter { p in
            let q = query.lowercased()
            let matchesQ = q.isEmpty || p.title.lowercased().contains(q) ||
                (p.client?.name.lowercased().contains(q) ?? false) ||
                (p.client?.company?.lowercased().contains(q) ?? false)
            let matchesStatus = statusFilter == nil || p.status == statusFilter
            return matchesQ && matchesStatus
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
                        Text("Error al cargar").font(.headline).foregroundStyle(Theme.textPrimary)
                        Text(error).font(.caption).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
                        Button("Reintentar") { Task { await load() } }
                            .buttonStyle(.borderedProminent)
                            .tint(Theme.gold)
                    }
                    .padding()
                } else if projects.isEmpty {
                    EmptyStateCard(
                        icon: "folder.badge.plus",
                        title: "Sin proyectos",
                        message: "Crea tu primer proyecto asignándolo a un cliente"
                    )
                    .padding(20)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            statusChips
                            ForEach(filtered) { project in
                                NavigationLink {
                                    ProjectDetailView(projectId: project.id)
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
            .searchable(text: $query, prompt: "Buscar proyecto o cliente")
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
                ProjectEditView(mode: .create) {
                    showCreate = false
                    Task { await load() }
                }
            }
        }
        .task { await load() }
    }

    private var statusChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(label: "Todos", isOn: statusFilter == nil) { statusFilter = nil }
                ForEach(statuses, id: \.self) { s in
                    Chip(label: s.capitalized, isOn: statusFilter == s) {
                        statusFilter = (statusFilter == s) ? nil : s
                    }
                }
            }
            .padding(.bottom, 4)
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            self.projects = try await APIClient.shared.listProjects()
            self.error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
