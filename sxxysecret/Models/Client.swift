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

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case company
        case email
        case phone
        case status
        case industry
        case website
        case notes
        case createdAt
        case updatedAt
    }

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

// MARK: - Task attachments (images/videos/docs)
struct TaskAttachment: Codable, Hashable, Identifiable {
    var id: String { url + filename }
    let url: String
    let filename: String
    let mimetype: String?
    let size: Int?
}

/// Chat attachment — same shape as TaskAttachment but also carries `kind`
/// (image / video / document) from the backend.
struct ChatAttachment: Codable, Hashable, Identifiable {
    var id: String { url + filename }
    let kind: String?
    let url: String
    let filename: String
    let mimetype: String?
    let size: Int?

    enum CodingKeys: String, CodingKey {
        case kind
        case url
        case filename
        case mimetype
        case size
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
    let project: ProjectLite?   // can be String id OR populated object
    let owner: UserRef?
    let assignee: UserRef?
    let images: [TaskAttachment]?
    let videos: [TaskAttachment]?
    let documents: [TaskAttachment]?
    let comments: [TaskComment]?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case title
        case description
        case status
        case priority
        case dueDate
        case project
        case owner
        case assignee
        case images
        case videos
        case documents
        case comments
        case createdAt
        case updatedAt
    }

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

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case text
        case author
        case createdAt
    }
}

// MARK: - Chat
struct Conversation: Codable, Identifiable, Hashable {
    let id: String
    let type: String?           // "direct" | "group"
    let name: String?
    let other: UserRef?
    let participants: [UserRef]?
    let lastMessageAt: Date?
    let lastMessage: ChatMessage?
    let unreadCount: Int?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case type
        case name
        case other
        case participants
        case lastMessageAt
        case lastMessage
        case unreadCount
    }
}

struct ChatMessage: Codable, Identifiable, Hashable {
    let id: String
    let conversationId: String?
    let conversation: String?
    let sender: String?         // user id, or
    let senderUser: UserRef?    // populated sender object
    let text: String
    let attachments: [ChatAttachment]?
    let readBy: [String]?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case conversationId
        case conversation
        case sender
        case senderUser
        case text
        case attachments
        case readBy
        case createdAt
    }
}

/// Paginated message response — backend returns { messages, hasMore, nextCursor }
struct MessagePage: Codable {
    let messages: [ChatMessage]
    let hasMore: Bool
    let nextCursor: String?
}

struct SendMessageRequest: Codable {
    let text: String
    let conversationId: String?
}
