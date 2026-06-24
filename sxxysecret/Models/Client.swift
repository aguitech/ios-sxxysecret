import Foundation

// MARK: - Client
// Backend fields: name, company, email, phone, notes, status: ['activo','pausado','baja'], owner
struct Client: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let company: String?
    let email: String?
    let phone: String?
    let notes: String?
    let status: String?         // activo, pausado, baja
    let owner: ClientOwner?     // can be String id or populated UserRef
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case name
        case company
        case email
        case phone
        case notes
        case status
        case owner
        case createdAt
        case updatedAt
    }

    init(id: String, name: String, company: String? = nil, email: String? = nil,
         phone: String? = nil, notes: String? = nil, status: String? = "activo",
         owner: ClientOwner? = nil, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.company = company
        self.email = email
        self.phone = phone
        self.notes = notes
        self.status = status
        self.owner = owner
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var initials: String {
        let parts = (company ?? name).split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }

    var statusLabel: String {
        switch status ?? "activo" {
        case "activo": return "Activo"
        case "pausado": return "Pausado"
        case "baja": return "Baja"
        default: return (status ?? "").capitalized
        }
    }

    var statusColor: String {
        switch status ?? "activo" {
        case "activo": return "green"
        case "pausado": return "orange"
        case "baja": return "red"
        default: return "gray"
        }
    }
}

/// Backend may return `owner` as either a String user ID or a populated UserRef.
enum ClientOwner: Codable, Hashable {
    case userId(String)
    case user(UserRef)

    var id: String {
        switch self {
        case .userId(let s): return s
        case .user(let u): return u.id
        }
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
    let client: ClientRef?
    let owner: UserRef?
    let assignee: UserRef?
    let images: [TaskAttachment]?
    let videos: [TaskAttachment]?
    let documents: [TaskAttachment]?
    let links: [TaskLink]?
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
        case client
        case owner
        case assignee
        case images
        case videos
        case documents
        case links
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

    var statusLabel: String {
        switch status {
        case "hecho": return "Hecha"
        case "en_curso": return "En curso"
        case "pendiente": return "Pendiente"
        default: return status.capitalized
        }
    }

    var priorityLabel: String {
        switch priority {
        case "alta": return "Alta"
        case "media": return "Media"
        case "baja": return "Baja"
        default: return priority.capitalized
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

struct TaskLink: Codable, Hashable, Identifiable {
    var id: String { url + (title ?? "") }
    let url: String
    let title: String?
    let description: String?
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

/// Chat sender — backend uses the same key `sender` for both shapes:
/// - listing endpoint: `"sender": "6a31..."` (just the user id)
/// - detail endpoint: `"sender": { "_id": "6a31...", "name": "...", ... }` (populated UserRef)
enum ChatSender: Codable, Hashable {
    case userId(String)
    case user(UserRef)

    var id: String {
        switch self {
        case .userId(let s): return s
        case .user(let u): return u.id
        }
    }

    var user: UserRef? {
        if case .user(let u) = self { return u }
        return nil
    }

    var name: String? {
        user?.name
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

struct ChatMessage: Codable, Identifiable, Hashable {
    let id: String
    let conversationId: String?
    let conversation: String?
    let sender: ChatSender
    let text: String
    let attachments: [ChatAttachment]?
    let readBy: [String]?
    let editedAt: Date?
    let deleted: Bool?
    let createdAt: Date
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case conversationId
        case conversation
        case sender
        case text
        case attachments
        case readBy
        case editedAt
        case deleted
        case createdAt
        case updatedAt
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
