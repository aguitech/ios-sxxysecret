import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Image(systemName: "square.grid.2x2.fill")
                    Text("Inicio")
                }
                .tag(0)

            ProjectsView()
                .tabItem {
                    Image(systemName: "folder.fill")
                    Text("Proyectos")
                }
                .tag(1)

            ClientsView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Clientes")
                }
                .tag(2)

            TasksView()
                .tabItem {
                    Image(systemName: "checklist")
                    Text("Tareas")
                }
                .tag(3)

            ProfileView()
                .tabItem {
                    Image(systemName: "person.crop.circle.fill")
                    Text("Perfil")
                }
                .tag(4)
        }
        .tint(Theme.gold)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthService.shared)
}
