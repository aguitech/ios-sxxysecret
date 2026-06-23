import Foundation

// MARK: - Client
struct Client: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let company: String?
    let email: String?
    let phone: String?
    let status: String?         // activo, inactivo, prospecto
    let industry: String?
    let website: String?
    let notes: String?
    let createdAt: Date?
    let updatedAt: Date?

    var initials: String {
        let parts = (company ?? name).split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }

    var statusLabel: String {
        (status ?? "activo").capitalized
    }
}

// MARK: - Task
struct ProjectTask: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String?
    let status: String          // pendiente, en_curso, hecho
    let priority: String        // baja, media, alta
    let dueDate: Date?
    let project: String?        // project id
    let owner: UserRef?
    let comments: [TaskComment]?
    let createdAt: Date?
    let updatedAt: Date?

    var statusColor: String {
        switch status {
        case "hecho": return "green"
        case "en_curso": return "blue"
        case "pendiente": return "orange"
        default: return "gray"
        }
    }

    var priorityColor: String {
        switch priority {
        case "alta": return "red"
        case "media": return "orange"
        case "baja": return "gray"
        default: return "gray"
        }
    }
}

struct TaskComment: Codable, Identifiable, Hashable {
    let id: String
    let text: String
    let author: UserRef
    let createdAt: Date
}
