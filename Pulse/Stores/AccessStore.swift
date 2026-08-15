import Foundation

/// Account approval gate. New accounts sit in `user_approvals` until approved
/// and the API refuses to serve them; this store asks `/me/access` where the
/// session stands. `approved == nil` means not yet checked.
@MainActor
final class AccessStore: ObservableObject {
    @Published private(set) var approved: Bool?
    @Published private(set) var isChecking = false

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func check() async {
        isChecking = true
        defer { isChecking = false }
        do {
            approved = try await api.accessStatus()
        } catch {
            // Fail open: the API enforces the gate regardless; don't strand
            // users on network hiccups.
            if approved == nil { approved = true }
        }
    }

    func reset() {
        approved = nil
    }
}
