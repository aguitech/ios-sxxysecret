import SwiftUI

/// Reusable form for creating or editing a user (admin only).
struct UserEditView: View {
    enum Mode {
        case create
        case edit(User)
    }

    let mode: Mode
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var password: String = ""
    @State private var role: String = "member"
    @State private var active: Bool = true

    @State private var saving = false
    @State private var error: String?

    private let roles = ["admin", "manager", "member", "client"]

    private var isEdit: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()

                Form {
                    Section("Datos básicos") {
                        labeledField("Nombre *", text: $name)
                        labeledField("Email *", text: $email, keyboard: .emailAddress)
                        labeledField("Teléfono", text: $phone, keyboard: .phonePad)
                    }
                    .listRowBackground(Theme.bgCard)

                    if !isEdit {
                        Section("Credenciales") {
                            SecureField("Contraseña * (mín. 6)", text: $password)
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .listRowBackground(Theme.bgCard)
                    }

                    Section("Rol y estado") {
                        Picker("Rol", selection: $role) {
                            ForEach(roles, id: \.self) { r in
                                Text(roleLabel(r)).tag(r)
                            }
                        }
                        .pickerStyle(.menu)
                        if isEdit {
                            Toggle("Activo", isOn: $active)
                        }
                    }
                    .listRowBackground(Theme.bgCard)

                    if let err = error {
                        Section {
                            Text(err).font(.caption).foregroundStyle(Theme.error)
                        }
                    }

                    Section {
                        Button {
                            Task { await save() }
                        } label: {
                            HStack {
                                Spacer()
                                if saving {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(isEdit ? "Guardar cambios" : "Crear usuario")
                                        .font(.headline)
                                }
                                Spacer()
                            }
                            .foregroundStyle(.white)
                            .padding(.vertical, 6)
                        }
                        .listRowBackground(Theme.gold)
                        .disabled(!isValid || saving)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(isEdit ? "Editar usuario" : "Nuevo usuario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bgPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.foregroundStyle(Theme.gold)
                }
            }
            .onAppear(perform: prefill)
        }
    }

    private var isValid: Bool {
        let n = name.trimmingCharacters(in: .whitespaces)
        let em = email.trimmingCharacters(in: .whitespaces)
        if isEdit {
            return !n.isEmpty && !em.isEmpty
        } else {
            return !n.isEmpty && !em.isEmpty && password.count >= 6
        }
    }

    @ViewBuilder
    private func labeledField(_ label: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.textPrimary).frame(width: 100, alignment: .leading)
            TextField(label, text: text)
                .keyboardType(keyboard)
                .autocapitalization(.none)
                .foregroundStyle(Theme.textPrimary)
        }
    }

    private func roleLabel(_ r: String) -> String {
        switch r {
        case "admin": return "Administrador"
        case "manager": return "Manager"
        case "member": return "Miembro"
        case "client": return "Cliente"
        default: return r.capitalized
        }
    }

    private func prefill() {
        if case .edit(let u) = mode {
            name = u.name
            email = u.email
            phone = u.phone ?? ""
            role = u.role
            active = u.active ?? true
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        let n = name.trimmingCharacters(in: .whitespaces)
        let em = email.trimmingCharacters(in: .whitespaces).lowercased()
        let ph = phone.trimmingCharacters(in: .whitespaces)
        do {
            switch mode {
            case .create:
                _ = try await APIClient.shared.createUser(
                    name: n,
                    email: em,
                    password: password,
                    role: role,
                    phone: ph.isEmpty ? nil : ph
                )
            case .edit(let u):
                _ = try await APIClient.shared.updateUser(
                    id: u.id,
                    name: n,
                    email: em,
                    role: role,
                    phone: ph.isEmpty ? nil : ph,
                    active: active
                )
            }
            onSaved()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
