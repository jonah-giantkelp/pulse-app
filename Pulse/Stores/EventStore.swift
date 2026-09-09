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
        // Tracked-city changes alter the server-side filter — refetch so the
        // Concerts feed updates without a manual pull-to-refresh. load()'s
        // silent-refresh path (no isLoading flip when events exist) means the
        // list swaps in place with no loading flash.
        NotificationCenter.default.addObserver(
            forName: .pulseCitiesChanged, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.load() }
        }
    }

    func load() async {
        // Avoid same-value @Published writes here: objectWillChange re-renders
        // the view at the start of pull-to-refresh, and that teardown cancels
        // the .refreshable task mid-request.
        if events.isEmpty { isLoading = true }
        defer { if isLoading { isLoading = false } }
        do {
            events = try await api.myEvents()
                .filter { !$0.isConcertsTrackerOnly }
                .sorted { $0.date < $1.date }
            loadError = nil
        } catch is CancellationError {
            // Refresh task torn down mid-flight — keep showing what we have.
        } catch let error as URLError where error.code == .cancelled {
            // Same teardown, surfaced through URLSession.
        } catch {
            // Cancellation can also arrive wrapped by other layers (auth
            // refresh, NSError -999) — never surface it as a load error.
            if Task.isCancelled || (error as NSError).code == NSURLErrorCancelled { return }
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
