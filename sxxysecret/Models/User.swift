import Foundation

// MARK: - User
// Backend returns MongoDB-shaped objects: `_id`, `createdAt`, etc.
// We decode `_id` -> `id` via CodingKeys and treat optional fields as such.
struct User: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let email: String
    let role: String
    let phone: String?
    let active: Bool?
    let lastLogin: Date?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case email
        case role
        case phone
        case active
        case lastLogin
        case createdAt
        case updatedAt
    }

    // Custom init: backend may omit optional fields, and ISO8601 may include
    // fractional seconds (e.g. ".984Z") which the default decoder rejects.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.email = try c.decode(String.self, forKey: .email)
        self.role = try c.decode(String.self, forKey: .role)
        self.phone = try c.decodeIfPresent(String.self, forKey: .phone)
        self.active = try c.decodeIfPresent(Bool.self, forKey: .active)
        self.lastLogin = User.flexDate(c, key: .lastLogin)
        self.createdAt = User.flexDate(c, key: .createdAt)
        self.updatedAt = User.flexDate(c, key: .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(email, forKey: .email)
        try c.encode(role, forKey: .role)
        try c.encodeIfPresent(phone, forKey: .phone)
        try c.encodeIfPresent(active, forKey: .active)
        try c.encodeIfPresent(lastLogin, forKey: .lastLogin)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }

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

    // ISO8601 with optional fractional seconds — backend emits ".984Z"
    private static func flexDate(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Date? {
        guard container.contains(key),
              let raw = try? container.decode(String.self, forKey: key) else { return nil }
        if let d = ISO8601DateFormatter.flexStrict.date(from: raw) { return d }
        return ISO8601DateFormatter.flexFractional.date(from: raw)
    }
}

extension ISO8601DateFormatter {
    static let flexStrict: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    static let flexFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
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
