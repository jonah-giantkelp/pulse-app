import Foundation

/// An artist the user just hit TRACK on — shown at the top of the Artists tab
/// with a spinner until the API finishes resolving/syncing it.
struct SyncingArtist: Identifiable, Hashable {
    var id: String { musicbrainzId }
    let musicbrainzId: String
    let name: String
    let imageUrl: String?
}

@MainActor
final class ArtistStore: ObservableObject {
    @Published private(set) var tracked: [UserArtist] = []
    @Published private(set) var syncing: [SyncingArtist] = []
    @Published private(set) var isLoading = false
    @Published var loadError: String?

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    var trackedMusicbrainzIds: Set<String> {
        Set(tracked.compactMap { $0.artists.musicbrainzId })
    }

    func load() async {
        isLoading = tracked.isEmpty
        defer { isLoading = false }
        do {
            tracked = try await api.trackedArtists()
                .sorted { $0.artists.name.localizedCaseInsensitiveCompare($1.artists.name) == .orderedAscending }
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    func search(query: String) async throws -> [ArtistSearchResult] {
        try await api.searchArtists(query: query)
    }

    /// Kicks off tracking. The POST can take 5-10s for new artists (AI platform
    /// resolution), so the artist sits in `syncing` until it lands in `tracked`.
    /// Returns an error message to surface, or nil on success.
    func track(_ result: ArtistSearchResult) async -> String? {
        guard !syncing.contains(where: { $0.musicbrainzId == result.musicbrainzId }) else { return nil }
        let pending = SyncingArtist(
            musicbrainzId: result.musicbrainzId,
            name: result.name,
            imageUrl: result.imageUrl
        )
        syncing.insert(pending, at: 0)
        defer { syncing.removeAll { $0.musicbrainzId == result.musicbrainzId } }

        do {
            _ = try await api.addArtist(musicbrainzId: result.musicbrainzId, name: result.name)
            await load()
            return nil
        } catch let error as APIError where error.status == 409 {
            await load()
            return "You're already tracking \(result.name)"
        } catch {
            return error.localizedDescription
        }
    }

    /// (in the user's locations, everywhere else) for the artist detail tabs.
    func detailEvents(for artistId: UUID) async -> (local: [Event], other: [Event]) {
        async let localFetch = api.artistEvents(id: artistId)
        async let allFetch = api.artistEvents(id: artistId, scopeAll: true)
        let local = (try? await localFetch) ?? []
        let all = (try? await allFetch) ?? []
        let localIds = Set(local.map(\.id))
        return (local, all.filter { !localIds.contains($0.id) })
    }

    func untrack(_ artistId: UUID) async {
        do {
            try await api.untrackArtist(id: artistId)
            tracked.removeAll { $0.artistId == artistId }
        } catch {
            loadError = error.localizedDescription
        }
    }
}
