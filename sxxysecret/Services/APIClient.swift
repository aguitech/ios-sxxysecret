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

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
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
                decoder.dateDecodingStrategy = .iso8601
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

    // MARK: Clients
    func listClients() async throws -> [Client] {
        try await request("GET", "/clients", type: [Client].self)
    }

    // MARK: Tasks
    func listTasks() async throws -> [ProjectTask] {
        try await request("GET", "/tasks", type: [ProjectTask].self)
    }
}
