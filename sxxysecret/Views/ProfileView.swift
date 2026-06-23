import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var auth: AuthService
    @State private var showLogoutConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Avatar grande
                        VStack(spacing: 12) {
                            Circle()
                                .fill(Theme.gold.opacity(0.2))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Text(auth.user?.initials ?? "?")
                                        .font(.system(size: 36, weight: .black))
                                        .foregroundStyle(Theme.gold)
                                )
                                .overlay(
                                    Circle().stroke(Theme.gold, lineWidth: 2)
                                )

                            VStack(spacing: 4) {
                                Text(auth.user?.name ?? "Usuario")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text(auth.user?.email ?? "")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textSecondary)
                                Text(auth.user?.roleLabel ?? "")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Theme.gold)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Theme.gold.opacity(0.15))
                                    .clipShape(Capsule())
                                    .textCase(.uppercase)
                                    .tracking(1)
                            }
                        }
                        .padding(.top, 16)

                        // Info card
                        VStack(spacing: 0) {
                            InfoRow(icon: "person.fill", title: "Nombre", value: auth.user?.name ?? "—")
                            Divider().background(Theme.bgSecondary)
                            InfoRow(icon: "envelope.fill", title: "Email", value: auth.user?.email ?? "—")
                            Divider().background(Theme.bgSecondary)
                            InfoRow(icon: "shield.lefthalf.filled", title: "Rol", value: auth.user?.roleLabel ?? "—")
                            Divider().background(Theme.bgSecondary)
                            InfoRow(icon: "phone.fill", title: "Teléfono", value: auth.user?.phone ?? "No especificado")
                        }
                        .background(Theme.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 20)

                        // App info
                        VStack(spacing: 8) {
                            Text("SxxySecret iOS")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.gold)
                            Text("v1.0.0 · Powered by Aguitech")
                                .font(.caption2)
                                .foregroundStyle(Theme.textTertiary)
                        }
                        .padding(.vertical, 12)

                        // Logout button
                        Button {
                            showLogoutConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                                Text("Cerrar sesión")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Theme.error.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Theme.error, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Perfil")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Theme.bgPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("¿Cerrar sesión?", isPresented: $showLogoutConfirm) {
                Button("Cancelar", role: .cancel) {}
                Button("Cerrar sesión", role: .destructive) {
                    auth.logout()
                }
            } message: {
                Text("Tendrás que volver a iniciar sesión")
            }
        }
        .task { await auth.refreshUser() }
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.gold)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(16)
    }
}
