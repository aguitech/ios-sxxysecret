import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Int = 0
    @State private var me: User? = AuthService.shared.user

    private var isAdmin: Bool { me?.role == "admin" }

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

            if isAdmin {
                UsersView()
                    .tabItem {
                        Image(systemName: "person.3.fill")
                        Text("Usuarios")
                    }
                    .tag(3)
            }

            NavigationStack { ChatListView() }
                .tabItem {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                    Text("Chat")
                }
                .tag(4)

            TasksView()
                .tabItem {
                    Image(systemName: "checklist")
                    Text("Tareas")
                }
                .tag(5)

            ProfileView()
                .tabItem {
                    Image(systemName: "person.crop.circle.fill")
                    Text("Perfil")
                }
                .tag(6)
        }
        .tint(Theme.gold)
        .onAppear {
            // Refresh me in case it changed (login)
            me = AuthService.shared.user
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthService.shared)
}
