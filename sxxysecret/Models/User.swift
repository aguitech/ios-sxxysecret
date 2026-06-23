import Foundation

// MARK: - User
struct User: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let email: String
    let role: String
    let phone: String?
    let active: Bool
    let lastLogin: Date?
    let createdAt: Date?
    let updatedAt: Date?

    var roleLabel: String {
        switch role {
        case "admin": return "Administrador"
        case "manager": return "Manager"
        case "member": return "Miembro"
        case "client": return "Cliente"
        default: return role.capitalized
        }
    }

    var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }
}

// MARK: - Auth Response
struct AuthResponse: Codable {
    let token: String
    let user: User
}

struct MeResponse: Codable {
    let user: User
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}
