import Foundation

// MARK: - Shared refs (used across models)
// Backend uses MongoDB `_id`. All refs map that to `id`.
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

struct ProjectMember: Codable, Hashable {
    let user: UserRef
    let role: String
    let addedAt: Date?
}

// MARK: - Project
struct Project: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let status: String
    let progress: Int
    let description: String?
    let budget: Double?
    let startDate: Date?
    let endDate: Date?
    let owner: UserRef?
    let client: ClientRef?
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
        case "cancelado": return "red"
        default: return "gray"
        }
    }

    var statusLabel: String { status.capitalized }
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
