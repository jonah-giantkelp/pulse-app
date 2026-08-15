import Foundation

/// Talks to Supabase auth REST directly (password grant + refresh) and keeps
/// the session in the Keychain. Only auth goes to Supabase — data goes through
/// the Flask API.
@MainActor
final class AuthManager: ObservableObject {
    struct Session: Codable {
        var accessToken: String
        var refreshToken: String
        var expiresAt: Date
        var email: String?
    }

    @Published private(set) var isAuthenticated = false
    @Published private(set) var email: String?

    private var session: Session?
    private var refreshTask: Task<Void, Error>?
    private static let keychainAccount = "session"

    init() {
        if let data = Keychain.load(account: Self.keychainAccount),
           let stored = try? JSONDecoder().decode(Session.self, from: data) {
            session = stored
            email = stored.email
            isAuthenticated = true
        }
    }

    // MARK: - Public API

    func signIn(email: String, password: String) async throws {
        let body = ["email": email, "password": password]
        let session = try await tokenRequest(path: "/auth/v1/token?grant_type=password", body: body)
        store(session)
    }

    func signUp(email: String, password: String) async throws {
        let url = Config.supabaseURL.appendingPathComponent("auth/v1/signup")
        let data = try await authPost(url: url, body: ["email": email, "password": password])
        if let session = parseSession(data) {
            store(session)
        } else {
            throw AuthError("Account created — confirm your email, then sign in.")
        }
    }

    func signOut() {
        session = nil
        email = nil
        isAuthenticated = false
        Keychain.delete(account: Self.keychainAccount)
    }

    /// Returns a token valid for at least the next minute, refreshing if needed.
    func validAccessToken() async throws -> String {
        guard let current = session else { throw AuthError("Not signed in") }
        if current.expiresAt > Date().addingTimeInterval(60) {
            return current.accessToken
        }
        try await refreshSession()
        guard let refreshed = session else { throw AuthError("Session expired") }
        return refreshed.accessToken
    }

    func refreshSession() async throws {
        if let running = refreshTask {
            try await running.value
            return
        }
        let task = Task {
            guard let current = session else { throw AuthError("Not signed in") }
            do {
                let refreshed = try await tokenRequest(
                    path: "/auth/v1/token?grant_type=refresh_token",
                    body: ["refresh_token": current.refreshToken]
                )
                store(refreshed)
            } catch {
                // A cancelled refresh (e.g. pull-to-refresh torn down by
                // SwiftUI) is not an auth failure — keep the session.
                let cancelled = error is CancellationError
                    || (error as NSError).code == NSURLErrorCancelled
                if !cancelled { signOut() }
                throw error
            }
        }
        refreshTask = task
        defer { refreshTask = nil }
        try await task.value
    }

    // MARK: - Internals

    private func store(_ session: Session) {
        self.session = session
        email = session.email
        isAuthenticated = true
        if let data = try? JSONEncoder().encode(session) {
            Keychain.save(data, account: Self.keychainAccount)
        }
    }

    private func tokenRequest(path: String, body: [String: String]) async throws -> Session {
        let url = URL(string: Config.supabaseURL.absoluteString + path)!
        let data = try await authPost(url: url, body: body)
        guard let session = parseSession(data) else {
            throw AuthError("Unexpected auth response")
        }
        return session
    }

    private func authPost(url: URL, body: [String: String]) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(Config.supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw AuthError(Self.errorMessage(from: data) ?? "Auth failed (\(status))")
        }
        return data
    }

    private func parseSession(_ data: Data) -> Session? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String,
              let refreshToken = json["refresh_token"] as? String else { return nil }
        let expiresIn = json["expires_in"] as? Double ?? 3600
        let email = (json["user"] as? [String: Any])?["email"] as? String
        return Session(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(expiresIn),
            email: email
        )
    }

    private static func errorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return (json["error_description"] as? String)
            ?? (json["msg"] as? String)
            ?? (json["message"] as? String)
            ?? (json["error"] as? String)
    }
}

struct AuthError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
