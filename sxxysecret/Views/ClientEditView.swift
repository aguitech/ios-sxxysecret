import SwiftUI

/// Reusable form for both creating a new client and editing an existing one.
struct ClientEditView: View {
    enum Mode {
        case create
        case edit(Client)
    }

    let mode: Mode
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var company: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var notes: String = ""
    @State private var status: String = "activo"

    @State private var saving = false
    @State private var error: String?

    private let statuses = ["activo", "pausado", "baja"]

    private var isEdit: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var navigationTitle: String {
        isEdit ? "Editar cliente" : "Nuevo cliente"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bgPrimary.ignoresSafeArea()

                Form {
                    Section("Datos básicos") {
                        field("Nombre", text: $name, required: true)
                        field("Empresa", text: $company)
                        field("Email", text: $email, keyboard: .emailAddress)
                        field("Teléfono", text: $phone, keyboard: .phonePad)
                    }
                    .listRowBackground(Theme.bgCard)

                    Section("Estado") {
                        Picker("Estado", selection: $status) {
                            ForEach(statuses, id: \.self) { s in
                                Text(s.capitalized).tag(s)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .listRowBackground(Theme.bgCard)

                    Section("Notas") {
                        TextField("Notas opcionales…", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .listRowBackground(Theme.bgCard)

                    if let err = error {
                        Section {
                            Text(err)
                                .font(.caption)
                                .foregroundStyle(Theme.error)
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
                                    Text(isEdit ? "Guardar cambios" : "Crear cliente")
                                        .font(.headline)
                                }
                                Spacer()
                            }
                            .foregroundStyle(.white)
                            .padding(.vertical, 6)
                        }
                        .listRowBackground(Theme.gold)
                        .disabled(saving || name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bgPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .foregroundStyle(Theme.gold)
                }
            }
            .onAppear(perform: prefill)
        }
    }

    @ViewBuilder
    private func field(_ label: String, text: Binding<String>, required: Bool = false, keyboard: UIKeyboardType = .default) -> some View {
        HStack {
            Text(required ? "\(label) *" : label)
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 90, alignment: .leading)
            TextField(label, text: text)
                .keyboardType(keyboard)
                .autocapitalization(.none)
                .foregroundStyle(Theme.textPrimary)
        }
    }

    private func prefill() {
        if case .edit(let c) = mode {
            name = c.name
            company = c.company ?? ""
            email = c.email ?? ""
            phone = c.phone ?? ""
            notes = c.notes ?? ""
            status = c.status ?? "activo"
        }
    }

    private func save() async {
        saving = true
        defer { saving = false }
        let n = name.trimmingCharacters(in: .whitespaces)
        let comp = company.trimmingCharacters(in: .whitespaces)
        let em = email.trimmingCharacters(in: .whitespaces)
        let ph = phone.trimmingCharacters(in: .whitespaces)
        let nt = notes.trimmingCharacters(in: .whitespaces)
        do {
            switch mode {
            case .create:
                _ = try await APIClient.shared.createClient(
                    name: n,
                    company: comp.isEmpty ? nil : comp,
                    email: em.isEmpty ? nil : em,
                    phone: ph.isEmpty ? nil : ph,
                    notes: nt.isEmpty ? nil : nt,
                    status: status
                )
            case .edit(let c):
                _ = try await APIClient.shared.updateClient(
                    id: c.id,
                    name: n,
                    company: comp.isEmpty ? nil : comp,
                    email: em.isEmpty ? nil : em,
                    phone: ph.isEmpty ? nil : ph,
                    notes: nt.isEmpty ? nil : nt,
                    status: status
                )
            }
            onSaved()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
