import Foundation

struct APIError: LocalizedError {
    let status: Int
    let message: String
    var errorDescription: String? { message }
}

final class APIClient {
    private let auth: AuthManager
    private let decoder: JSONDecoder

    init(auth: AuthManager) {
        self.auth = auth

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let plain = ISO8601DateFormatter()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { d in
            let raw = try d.singleValueContainer().decode(String.self)
            if let date = plain.date(from: raw) ?? fractional.date(from: raw) { return date }
            throw DecodingError.dataCorrupted(.init(
                codingPath: d.codingPath, debugDescription: "Unparseable date: \(raw)"
            ))
        }
        self.decoder = decoder
    }

    // MARK: - Endpoints

    func searchArtists(query: String, limit: Int = 5) async throws -> [ArtistSearchResult] {
        try await request("GET", "/artists/search/musicbrainz", query: [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
        ])
    }

    func addArtist(musicbrainzId: String, name: String, city: String? = nil) async throws -> AddArtistResponse {
        var body: [String: Any] = ["musicbrainz_id": musicbrainzId, "name": name]
        if let city { body["city"] = city }
        // New artists get platform resolution + an initial event sync — slow
        return try await request("POST", "/artists", body: body, timeout: 180)
    }

    func trackedArtists() async throws -> [UserArtist] {
        try await request("GET", "/me/artists")
    }

    func untrackArtist(id: UUID) async throws {
        let _: StatusResponse = try await request("DELETE", "/me/artists/\(id.uuidString.lowercased())")
    }

    /// Default scope applies the user's default_cities/default_countries
    /// server-side; scope=all returns every location.
    func myEvents(scopeAll: Bool = false) async throws -> [Event] {
        let query = scopeAll ? [URLQueryItem(name: "scope", value: "all")] : []
        return try await request("GET", "/me/events", query: query)
    }

    func artistEvents(id: UUID, scopeAll: Bool = false) async throws -> [Event] {
        let query = scopeAll ? [URLQueryItem(name: "scope", value: "all")] : []
        return try await request("GET", "/artists/\(id.uuidString.lowercased())/events", query: query)
    }

    func favouriteEvents() async throws -> [Event] {
        try await request("GET", "/me/favourites")
    }

    func addFavourite(eventId: UUID) async throws {
        let _: StatusResponse = try await request("POST", "/me/favourites/\(eventId.uuidString.lowercased())")
    }

    func removeFavourite(eventId: UUID) async throws {
        let _: StatusResponse = try await request("DELETE", "/me/favourites/\(eventId.uuidString.lowercased())")
    }

    func emailPreferences() async throws -> EmailPreferences {
        try await request("GET", "/me/email-preferences")
    }

    func updateEmailPreferences(
        digestEnabled: Bool, recipients: [String], pushEnabled: Bool
    ) async throws -> EmailPreferences {
        try await request("PUT", "/me/email-preferences", body: [
            "digest_enabled": digestEnabled,
            "recipients": recipients,
            "push_enabled": pushEnabled,
        ])
    }

    func registerPushToken(_ token: String) async throws {
        let _: StatusResponse = try await request(
            "POST", "/me/push-token", body: ["device_token": token, "platform": "ios"]
        )
    }

    func deletePushToken(_ token: String) async throws {
        let _: StatusResponse = try await request("DELETE", "/me/push-token/\(token)")
    }

    func deleteAccount() async throws {
        let _: StatusResponse = try await request("DELETE", "/me/account")
    }

    // MARK: - Core request

    private func request<T: Decodable>(
        _ method: String, _ path: String,
        query: [URLQueryItem] = [], body: [String: Any]? = nil,
        timeout: TimeInterval = 60
    ) async throws -> T {
        let data = try await send(method, path, query: query, body: body, timeout: timeout, retryOn401: true)
        return try decoder.decode(T.self, from: data)
    }

    private func send(
        _ method: String, _ path: String,
        query: [URLQueryItem], body: [String: Any]?, timeout: TimeInterval, retryOn401: Bool
    ) async throws -> Data {
        var components = URLComponents(
            url: Config.apiBaseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        if !query.isEmpty { components.queryItems = query }

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.timeoutInterval = timeout
        let token = try await auth.validAccessToken()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        if status == 401 && retryOn401 {
            try await auth.refreshSession()
            return try await send(method, path, query: query, body: body, timeout: timeout, retryOn401: false)
        }
        guard (200..<300).contains(status) else {
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let message = json?["error"] as? String ?? "Request failed (\(status))"
            throw APIError(status: status, message: message)
        }
        return data
    }
}
