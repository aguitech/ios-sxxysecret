import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthService
    @State private var email = "admin@aguittech.com"
    @State private var password = "admin123"
    @State private var showPassword = false
    @FocusState private var focused: Field?

    enum Field { case email, password }

    var body: some View {
        ZStack {
            // Fondo
            Theme.bgPrimary.ignoresSafeArea()

            // Glow dorado
            RadialGradient(
                colors: [Theme.gold.opacity(0.25), .clear],
                center: .top,
                startRadius: 50,
                endRadius: 500
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Logo
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Theme.gold.opacity(0.15))
                            .frame(width: 110, height: 110)
                        Text("🔥")
                            .font(.system(size: 56))
                    }
                    Text("SxxySecret")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.gold)
                    Text("Aguitech Core")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                        .textCase(.uppercase)
                        .tracking(3)
                }

                Spacer()

                // Form
                VStack(spacing: 16) {
                    InputField(
                        icon: "envelope.fill",
                        placeholder: "Email",
                        text: $email,
                        isSecure: false,
                        keyboard: .emailAddress
                    )
                    .focused($focused, equals: .email)

                    InputField(
                        icon: "lock.fill",
                        placeholder: "Contraseña",
                        text: $password,
                        isSecure: !showPassword,
                        keyboard: .default
                    )
                    .focused($focused, equals: .password)
                    .overlay(alignment: .trailing) {
                        Button {
                            showPassword.toggle()
                        } label: {
                            Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                .foregroundStyle(Theme.textTertiary)
                                .padding(.trailing, 16)
                        }
                    }
                }
                .padding(.horizontal, 32)

                // Error
                if let err = auth.errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(err)
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.error)
                    .padding(.horizontal, 32)
                    .multilineTextAlignment(.center)
                }

                // Botón login
                Button {
                    Task {
                        focused = nil
                        await auth.login(email: email, password: password)
                    }
                } label: {
                    HStack(spacing: 12) {
                        if auth.isLoading {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text("Iniciar sesión")
                                .font(.system(size: 17, weight: .bold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Theme.gold)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Theme.gold.opacity(0.4), radius: 20, y: 8)
                }
                .disabled(auth.isLoading || email.isEmpty || password.isEmpty)
                .padding(.horizontal, 32)

                Spacer()

                Text("v1.0 · Powered by Aguitech")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.bottom, 24)
            }
        }
    }
}

struct InputField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let isSecure: Bool
    let keyboard: UIKeyboardType

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(Theme.gold)
                .frame(width: 22)
                .font(.system(size: 16, weight: .semibold))

            if isSecure {
                SecureField(placeholder, text: $text)
                    .textContentType(.password)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 56)
        .background(Theme.bgCard)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.gold.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .foregroundStyle(Theme.textPrimary)
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthService.shared)
        .background(Theme.bgPrimary)
}
