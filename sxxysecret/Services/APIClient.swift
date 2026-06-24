import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case noData
    case decoding(Error)
    case server(Int, String)
    case network(Error)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "URL inválida"
        case .noData: return "Sin datos del servidor"
        case .decoding(let e): return "Error de decodificación: \(e.localizedDescription)"
        case .server(_, let msg): return msg
        case .network(let e): return "Error de red: \(e.localizedDescription)"
        case .unauthorized: return "Sesión expirada. Inicia sesión de nuevo."
        }
    }
}

actor APIClient {
    static let shared = APIClient()
    private let baseURL = "https://sxxysecret.com/api"
    private let session: URLSession

    static let iso8601Strict: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static let iso8601Fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 90
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    private func request<T: Decodable>(
        _ method: String,
        _ path: String,
        body: [String: Any]? = nil,
        authenticated: Bool = true,
        type: T.Type
    ) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("iOSApp/1.0", forHTTPHeaderField: "User-Agent")

        if authenticated {
            let token = await MainActor.run { AuthService.shared.currentToken() }
            if let token = token {
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        if let body = body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else { throw APIError.noData }

            if http.statusCode == 401 {
                throw APIError.unauthorized
            }

            if http.statusCode >= 400 {
                let msg: String
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let m = json["message"] as? String {
                    msg = m
                } else {
                    msg = "Error \(http.statusCode)"
                }
                throw APIError.server(http.statusCode, msg)
            }

            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .custom { dec in
                    let container = try dec.singleValueContainer()
                    let raw = try container.decode(String.self)
                    if let d = APIClient.iso8601Strict.date(from: raw) { return d }
                    if let d = APIClient.iso8601Fractional.date(from: raw) { return d }
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(raw)")
                }
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decoding(error)
            }
        } catch let err as APIError {
            throw err
        } catch {
            throw APIError.network(error)
        }
    }

    /// Multipart upload — used for chat attachments.
    /// `files` are uploaded under the field name "files" (matches server's multer config).
    /// Backend saves them to /api/uploads/ and returns the populated message with attachment URLs.
    private func uploadMultipart<T: Decodable>(
        _ path: String,
        text: String?,
        files: [(name: String, data: Data, mimeType: String)],
        type: T.Type
    ) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        let boundary = "Boundary-\(UUID().uuidString)"
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("iOSApp/1.0", forHTTPHeaderField: "User-Agent")
        let token = await MainActor.run { AuthService.shared.currentToken() }
        if let token = token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        var body = Data()
        func appendString(_ s: String) { body.append(s.data(using: .utf8)!) }
        if let text = text, !text.isEmpty {
            appendString("--\(boundary)\r\n")
            appendString("Content-Disposition: form-data; name=\"text\"\r\n\r\n")
            appendString("\(text)\r\n")
        }
        for f in files {
            appendString("--\(boundary)\r\n")
            appendString("Content-Disposition: form-data; name=\"files\"; filename=\"\(f.name)\"\r\n")
            appendString("Content-Type: \(f.mimeType)\r\n\r\n")
            body.append(f.data)
            appendString("\r\n")
        }
        appendString("--\(boundary)--\r\n")
        req.httpBody = body

        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else { throw APIError.noData }
            if http.statusCode == 401 { throw APIError.unauthorized }
            if http.statusCode >= 400 {
                let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String
                    ?? "Error \(http.statusCode)"
                throw APIError.server(http.statusCode, msg)
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { dec in
                let c = try dec.singleValueContainer()
                let raw = try c.decode(String.self)
                if let d = APIClient.iso8601Strict.date(from: raw) { return d }
                if let d = APIClient.iso8601Fractional.date(from: raw) { return d }
                throw DecodingError.dataCorruptedError(in: c, debugDescription: "Invalid date: \(raw)")
            }
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decoding(error)
            }
        } catch let err as APIError {
            throw err
        } catch {
            throw APIError.network(error)
        }
    }

    // MARK: Auth
    func login(email: String, password: String) async throws -> AuthResponse {
        try await request("POST", "/auth/login", body: ["email": email, "password": password], authenticated: false, type: AuthResponse.self)
    }

    func me() async throws -> MeResponse {
        try await request("GET", "/auth/me", type: MeResponse.self)
    }

    // MARK: Dashboard
    func dashboardStats() async throws -> DashboardStats {
        try await request("GET", "/dashboard/stats", type: DashboardStats.self)
    }

    func dashboardProjects() async throws -> [Project] {
        try await request("GET", "/dashboard/projects", type: [Project].self)
    }

    func projectDetail(id: String) async throws -> ProjectDetail {
        try await request("GET", "/dashboard/projects/\(id)", type: ProjectDetail.self)
    }

    // MARK: Clients (CRUD)
    func listClients(q: String? = nil, status: String? = nil) async throws -> [Client] {
        var path = "/clients"
        var qs: [String] = []
        if let q = q, !q.isEmpty { qs.append("q=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)") }
        if let status = status, !status.isEmpty { qs.append("status=\(status)") }
        if !qs.isEmpty { path += "?" + qs.joined(separator: "&") }
        return try await request("GET", path, type: [Client].self)
    }

    func createClient(name: String, company: String?, email: String?, phone: String?, notes: String?, status: String?) async throws -> Client {
        var body: [String: Any] = ["name": name]
        if let v = company, !v.isEmpty { body["company"] = v }
        if let v = email, !v.isEmpty { body["email"] = v }
        if let v = phone, !v.isEmpty { body["phone"] = v }
        if let v = notes, !v.isEmpty { body["notes"] = v }
        if let v = status, !v.isEmpty { body["status"] = v }
        return try await request("POST", "/clients", body: body, type: Client.self)
    }

    func updateClient(id: String, name: String, company: String?, email: String?, phone: String?, notes: String?, status: String?) async throws -> Client {
        var body: [String: Any] = ["name": name]
        if let v = company { body["company"] = v }
        if let v = email { body["email"] = v }
        if let v = phone { body["phone"] = v }
        if let v = notes { body["notes"] = v }
        if let v = status { body["status"] = v }
        return try await request("PUT", "/clients/\(id)", body: body, type: Client.self)
    }

    func deleteClient(id: String) async throws {
        try await requestNoBody("DELETE", "/clients/\(id)")
    }

    // MARK: Tasks (CRUD)
    func listTasks() async throws -> [ProjectTask] {
        try await request("GET", "/tasks", type: [ProjectTask].self)
    }

    func createTask(title: String, description: String?, status: String, priority: String,
                    projectId: String?, clientId: String?, assigneeId: String?, dueDate: Date?) async throws -> ProjectTask {
        var body: [String: Any] = ["title": title, "status": status, "priority": priority]
        if let v = description, !v.isEmpty { body["description"] = v }
        if let v = projectId { body["project"] = v }
        if let v = clientId { body["client"] = v }
        if let v = assigneeId { body["assignee"] = v }
        if let v = dueDate {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            body["dueDate"] = f.string(from: v)
        }
        return try await request("POST", "/tasks", body: body, type: ProjectTask.self)
    }

    func updateTask(id: String, title: String?, description: String?, status: String?,
                    priority: String?, projectId: String?, assigneeId: String?, dueDate: Date?) async throws -> ProjectTask {
        var body: [String: Any] = [:]
        if let v = title { body["title"] = v }
        if let v = description { body["description"] = v }
        if let v = status { body["status"] = v }
        if let v = priority { body["priority"] = v }
        if let v = projectId { body["project"] = v.isEmpty ? NSNull() : v }
        if let v = assigneeId { body["assignee"] = v.isEmpty ? NSNull() : v }
        if let v = dueDate {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            body["dueDate"] = f.string(from: v)
        }
        return try await request("PUT", "/tasks/\(id)", body: body, type: ProjectTask.self)
    }

    func deleteTask(id: String) async throws {
        try await requestNoBody("DELETE", "/tasks/\(id)")
    }

    // MARK: Projects (CRUD)
    /// Project routes are mounted under /dashboard per server.js
    func listProjects(q: String? = nil, status: String? = nil, clientId: String? = nil) async throws -> [Project] {
        var path = "/dashboard/projects"
        var qs: [String] = []
        if let q = q, !q.isEmpty { qs.append("q=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)") }
        if let status = status, !status.isEmpty { qs.append("status=\(status)") }
        if let v = clientId, !v.isEmpty { qs.append("client=\(v)") }
        if !qs.isEmpty { path += "?" + qs.joined(separator: "&") }
        return try await request("GET", path, type: [Project].self)
    }

    func getProject(id: String) async throws -> Project {
        try await request("GET", "/dashboard/projects/\(id)", type: Project.self)
    }

    func getProjectDetail(id: String) async throws -> ProjectDetail {
        try await request("GET", "/dashboard/projects/\(id)/detail", type: ProjectDetail.self)
    }

    func createProject(title: String, description: String?, clientId: String, status: String,
                       progress: Int, budget: Double?, startDate: Date?, endDate: Date?,
                       memberEmails: [String: String] = [:]) async throws -> Project {
        var body: [String: Any] = [
            "title": title,
            "clientId": clientId,
            "status": status,
            "progress": progress,
        ]
        if let v = description, !v.isEmpty { body["description"] = v }
        if let v = budget { body["budget"] = v }
        if let v = startDate {
            let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            body["startDate"] = f.string(from: v)
        }
        if let v = endDate {
            let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            body["endDate"] = f.string(from: v)
        }
        return try await request("POST", "/dashboard/projects", body: body, type: Project.self)
    }

    func updateProject(id: String, title: String?, description: String?, clientId: String?,
                       status: String?, progress: Int?, budget: Double?,
                       startDate: Date?, endDate: Date?) async throws -> Project {
        var body: [String: Any] = [:]
        if let v = title { body["title"] = v }
        if let v = description { body["description"] = v }
        if let v = clientId { body["clientId"] = v }
        if let v = status { body["status"] = v }
        if let v = progress { body["progress"] = v }
        if let v = budget { body["budget"] = v }
        if let v = startDate {
            let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            body["startDate"] = f.string(from: v)
        }
        if let v = endDate {
            let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            body["endDate"] = f.string(from: v)
        }
        return try await request("PUT", "/dashboard/projects/\(id)", body: body, type: Project.self)
    }

    func deleteProject(id: String) async throws {
        try await requestNoBody("DELETE", "/dashboard/projects/\(id)")
    }

    /// Add a member to a project by their EMAIL (backend resolves user from email) + role.
    func addProjectMember(projectId: String, email: String, role: String = "colaborador") async throws {
        try await requestNoBody("POST", "/dashboard/projects/\(projectId)/members", body: ["email": email, "role": role])
    }

    func removeProjectMember(projectId: String, userId: String) async throws {
        try await requestNoBody("DELETE", "/dashboard/projects/\(projectId)/members/\(userId)")
    }

    // MARK: Users (CRUD — admin)
    func listUsers(q: String? = nil, role: String? = nil) async throws -> [User] {
        var path = "/users"
        var qs: [String] = []
        if let q = q, !q.isEmpty { qs.append("q=\(q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q)") }
        if let role = role, !role.isEmpty { qs.append("role=\(role)") }
        if !qs.isEmpty { path += "?" + qs.joined(separator: "&") }
        return try await request("GET", path, type: [User].self)
    }

    func getUser(id: String) async throws -> User {
        try await request("GET", "/users/\(id)", type: User.self)
    }

    func createUser(name: String, email: String, password: String, role: String, phone: String?) async throws -> User {
        var body: [String: Any] = [
            "name": name,
            "email": email,
            "password": password,
            "role": role,
        ]
        if let v = phone, !v.isEmpty { body["phone"] = v }
        return try await request("POST", "/users", body: body, type: User.self)
    }

    func updateUser(id: String, name: String?, email: String?, role: String?, phone: String?, active: Bool?) async throws -> User {
        var body: [String: Any] = [:]
        if let v = name { body["name"] = v }
        if let v = email { body["email"] = v }
        if let v = role { body["role"] = v }
        if let v = phone { body["phone"] = v }
        if let v = active { body["active"] = v }
        return try await request("PUT", "/users/\(id)", body: body, type: User.self)
    }

    func deleteUser(id: String) async throws {
        try await requestNoBody("DELETE", "/users/\(id)")
    }

    // MARK: Chat
    func listConversations() async throws -> [Conversation] {
        try await request("GET", "/chat/conversations", type: [Conversation].self)
    }

    /// listMessages returns paginated { messages, hasMore, nextCursor }
    func listMessages(conversationId: String, cursor: String? = nil, since: String? = nil) async throws -> MessagePage {
        var path = "/chat/conversations/\(conversationId)/messages"
        var qs: [String] = []
        if let cursor = cursor { qs.append("cursor=\(cursor)") }
        if let since = since { qs.append("since=\(since)") }
        if !qs.isEmpty { path += "?" + qs.joined(separator: "&") }
        return try await request("GET", path, type: MessagePage.self)
    }

    /// Send a text-only message
    func sendMessage(conversationId: String, text: String) async throws -> ChatMessage {
        try await request(
            "POST",
            "/chat/conversations/\(conversationId)/messages",
            body: ["text": text],
            type: ChatMessage.self
        )
    }

    /// Send a message with attachments (multipart/form-data with field "files")
    func sendMessageWithAttachments(conversationId: String, text: String?, files: [(name: String, data: Data, mimeType: String)]) async throws -> ChatMessage {
        try await uploadMultipart(
            "/chat/conversations/\(conversationId)/messages",
            text: text,
            files: files,
            type: ChatMessage.self
        )
    }

    /// Open or fetch a 1-on-1 conversation by the other user's email
    func openConversationByEmail(email: String) async throws -> Conversation {
        try await request(
            "POST",
            "/chat/conversations",
            body: ["email": email],
            type: Conversation.self
        )
    }

    /// Fire-and-forget POST
    func requestNoBody(_ method: String, _ path: String, body: [String: Any]? = nil) async throws {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("iOSApp/1.0", forHTTPHeaderField: "User-Agent")
        let token = await MainActor.run { AuthService.shared.currentToken() }
        if let token = token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body = body { req.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (_, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIError.noData }
        if http.statusCode == 401 { throw APIError.unauthorized }
        if http.statusCode >= 400 {
            let msg = "Error \(http.statusCode)"
            throw APIError.server(http.statusCode, msg)
        }
    }
}
