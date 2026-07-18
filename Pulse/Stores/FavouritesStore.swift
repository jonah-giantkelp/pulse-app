import Foundation

/// API-backed favourites (user_event_favourites table). Toggles optimistically
/// and reverts on failure. Migrates any pre-API favourites out of UserDefaults
/// on first load.
@MainActor
final class FavouritesStore: ObservableObject {
    @Published private(set) var ids: Set<UUID> = []
    @Published private(set) var events: [Event] = []
    @Published private(set) var isLoading = false

    private let api: APIClient
    private static let legacyKey = "favouriteEventIds"

    init(api: APIClient) {
        self.api = api
    }

    func load() async {
        isLoading = events.isEmpty
        defer { isLoading = false }
        await migrateLegacyLocalFavourites()
        if let fetched = try? await api.favouriteEvents() {
            events = fetched
            ids = Set(fetched.map(\.id))
        }
    }

    func contains(_ event: Event) -> Bool {
        ids.contains(event.id)
    }

    func toggle(_ event: Event) {
        let adding = !ids.contains(event.id)
        apply(event, adding: adding)
        Task {
            do {
                if adding {
                    try await api.addFavourite(eventId: event.id)
                } else {
                    try await api.removeFavourite(eventId: event.id)
                }
            } catch {
                apply(event, adding: !adding) // revert optimistic change
            }
        }
    }

    private func apply(_ event: Event, adding: Bool) {
        if adding {
            ids.insert(event.id)
            events.append(event)
            events.sort { $0.date < $1.date }
        } else {
            ids.remove(event.id)
            events.removeAll { $0.id == event.id }
        }
    }

    private func migrateLegacyLocalFavourites() async {
        let stored = UserDefaults.standard.stringArray(forKey: Self.legacyKey) ?? []
        guard !stored.isEmpty else { return }
        for id in stored.compactMap(UUID.init) {
            try? await api.addFavourite(eventId: id)
        }
        UserDefaults.standard.removeObject(forKey: Self.legacyKey)
    }
}
