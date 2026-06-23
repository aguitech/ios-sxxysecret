import Foundation
import SwiftUI

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published private(set) var user: User?
    @Published private(set) var token: String?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    var isAuthenticated: Bool { token != nil && user != nil }

    private init() {
        self.token = Keychain.read("jwt_token")
        if let userData = Keychain.read("user_json"),
           let data = userData.data(using: .utf8) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            self.user = try? decoder.decode(User.self, from: data)
        }
    }

    // Non-isolated helpers for use from actor contexts
    nonisolated func currentToken() -> String? {
        Keychain.read("jwt_token")
    }

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await APIClient.shared.login(email: email, password: password)
            self.token = response.token
            self.user = response.user

            Keychain.save(response.token, key: "jwt_token")
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(response.user),
               let json = String(data: data, encoding: .utf8) {
                Keychain.save(json, key: "user_json")
            }
        } catch let err as APIError {
            errorMessage = err.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshUser() async {
        guard token != nil else { return }
        do {
            let response = try await APIClient.shared.me()
            self.user = response.user
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(response.user),
               let json = String(data: data, encoding: .utf8) {
                Keychain.save(json, key: "user_json")
            }
        } catch {
            // Silenciar
        }
    }

    func logout() {
        self.token = nil
        self.user = nil
        Keychain.delete("jwt_token")
        Keychain.delete("user_json")
    }
}
