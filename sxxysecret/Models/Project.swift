import Foundation
import SwiftUI

// MARK: - Shared refs (used across models)
// Backend uses MongoDB `_id`. All refs map that to `id`.
// `owner` on a Project can come back as either a String ID or a UserRef
// object — handle both via a custom decoder.
struct UserRef: Codable, Hashable {
    let id: String
    let name: String
    let email: String?
    let role: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case email
        case role
    }
}

struct ClientRef: Codable, Hashable {
    let id: String
    let name: String
    let company: String?
    let email: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case company
        case email
        case status
    }
}

/// A flexible "owner" field — backend sometimes returns a string ID,
/// sometimes a populated user object.
enum ProjectOwner: Codable, Hashable {
    case userId(String)
    case user(UserRef)

    var id: String {
        switch self {
        case .userId(let s): return s
        case .user(let u): return u.id
        }
    }

    var name: String? {
        if case .user(let u) = self { return u.name }
        return nil
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) {
            self = .userId(s)
            return
        }
        if let u = try? c.decode(UserRef.self) {
            self = .user(u)
            return
        }
        self = .userId("")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .userId(let s): try c.encode(s)
        case .user(let u): try c.encode(u)
        }
    }
}

struct ProjectMember: Codable, Hashable {
    let user: UserRef
    let role: String
    let addedAt: Date?
}

/// A project's `project` field on a Task can come back as either a string
/// ID (light listing) or a populated object with title/status.
enum ProjectLite: Codable, Hashable {
    case projectId(String)
    case populated(_id: String, title: String, status: String?)

    var id: String {
        switch self {
        case .projectId(let s): return s
        case .populated(let pid, _, _): return pid
        }
    }

    var title: String? {
        if case .populated(_, let t, _) = self { return t }
        return nil
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) {
            self = .projectId(s)
            return
        }
        struct PopulatedShape: Decodable { let _id: String; let title: String; let status: String? }
        if let p = try? c.decode(PopulatedShape.self) {
            self = .populated(_id: p._id, title: p.title, status: p.status)
            return
        }
        self = .projectId("")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .projectId(let s): try c.encode(s)
        case .populated(let pid, let t, let st):
            struct P: Encodable { let _id: String; let title: String; let status: String? }
            try c.encode(P(_id: pid, title: t, status: st))
        }
    }
}

// MARK: - Project
struct Project: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let status: String           // activo, pausado, completado
    let progress: Int            // 0-100
    let description: String?
    let budget: Double?
    let startDate: Date?
    let endDate: Date?
    let owner: ProjectOwner?     // can be String id or populated UserRef
    let client: ClientRef?       // can be populated { _id, name, company, email, status }
    let members: [ProjectMember]?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title
        case status
        case progress
        case description
        case budget
        case startDate
        case endDate
        case owner
        case client
        case members
        case createdAt
        case updatedAt
    }

    var statusColor: String {
        switch status {
        case "activo": return "green"
        case "completado": return "blue"
        case "pausado": return "orange"
        default: return "gray"
        }
    }

    var statusLabel: String {
        switch status {
        case "activo": return "Activo"
        case "completado": return "Completado"
        case "pausado": return "Pausado"
        default: return status.capitalized
        }
    }
}

// MARK: - Project Member Roles
enum ProjectMemberRole: String, CaseIterable, Codable, Identifiable {
    case colaborador
    case revisor
    case observador

    var id: String { rawValue }

    var label: String {
        switch self {
        case .colaborador: return "Colaborador"
        case .revisor: return "Revisor"
        case .observador: return "Observador"
        }
    }

    var description: String {
        switch self {
        case .colaborador: return "Puede editar tareas"
        case .revisor: return "Puede ver y comentar"
        case .observador: return "Solo ver"
        }
    }

    var colorName: String {
        switch self {
        case .colaborador: return "blue"
        case .revisor: return "purple"
        case .observador: return "gray"
        }
    }

    var color: Color {
        switch self {
        case .colaborador: return Theme.info
        case .revisor: return Theme.accent
        case .observador: return Theme.textTertiary
        }
    }
}

// MARK: - Dashboard Stats
struct DashboardStats: Codable {
    let total: Int
    let activos: Int
    let completados: Int
    let promedio: Int
}

struct ProjectDetail: Codable {
    let project: Project
    let stats: ProjectStats
    let tasks: [ProjectTask]
    let memberStats: [MemberStat]
    let recentComments: [Comment]
}

struct ProjectStats: Codable {
    let totalTasks: Int
    let byStatus: StatusBreakdown
    let byPriority: PriorityBreakdown
    let weightedProgress: Int
    let manualProgress: Int
    let overdue: Int
    let upcomingCount: Int
    let nextDeadline: NextDeadline?
    let membersCount: Int
}

struct StatusBreakdown: Codable {
    let pendiente: Int
    let en_curso: Int
    let hecho: Int
}

struct PriorityBreakdown: Codable {
    let baja: Int
    let media: Int
    let alta: Int
}

struct NextDeadline: Codable {
    let taskId: String
    let title: String
    let dueDate: Date
}

struct MemberStat: Codable, Identifiable {
    var id: String { user.id }
    let user: UserRef
    let role: String
    let addedAt: Date?
    let tasksOwned: Int
    let tasksCompleted: Int
}

struct Comment: Codable, Identifiable {
    let id: String
    let text: String
    let author: UserRef
    let createdAt: Date
    let taskId: String
    let taskTitle: String

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case text
        case author
        case createdAt
        case taskId
        case taskTitle
    }
}
