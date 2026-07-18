import Foundation

@MainActor
final class EventStore: ObservableObject {
    /// Upcoming events in the user's default cities/countries (server-filtered).
    @Published private(set) var events: [Event] = []
    @Published private(set) var isLoading = false
    @Published var loadError: String?

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func load() async {
        isLoading = events.isEmpty
        defer { isLoading = false }
        do {
            events = try await api.myEvents().sorted { $0.date < $1.date }
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Events grouped by calendar day, soonest first.
    static func byDay(_ events: [Event]) -> [(day: Date, events: [Event])] {
        Dictionary(grouping: events) { Calendar.current.startOfDay(for: $0.date) }
            .sorted { $0.key < $1.key }
            .map { (day: $0.key, events: $0.value.sorted { $0.date < $1.date }) }
    }
}
