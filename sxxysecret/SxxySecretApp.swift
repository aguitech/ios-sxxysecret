import SwiftUI

@main
struct SxxySecretApp: App {
    @StateObject private var auth = AuthService.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .preferredColorScheme(.light)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var auth: AuthService

    var body: some View {
        Group {
            if auth.isAuthenticated {
                MainTabView()
                    .transition(.opacity)
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: auth.isAuthenticated)
    }
}
