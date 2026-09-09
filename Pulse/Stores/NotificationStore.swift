import Foundation

/// In-app notification feed (user_notifications table), written server-side
/// by the digest job. Mark-as-read is optimistic — the badge clears
/// immediately and the API call catches up.
@MainActor
final class NotificationStore: ObservableObject {
    @Published private(set) var notifications: [UserNotification] = []
    @Published private(set) var isLoading = false

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    var unreadCount: Int {
        notifications.filter { $0.readAt == nil }.count
    }

    func load() async {
        isLoading = notifications.isEmpty
        defer { isLoading = false }
        if let fetched = try? await api.notifications() {
            notifications = fetched.filter { !$0.event.isConcertsTrackerOnly }
        }
    }

    func markAllRead() {
        guard unreadCount > 0 else { return }
        let now = Date()
        notifications = notifications.map { notification in
            var updated = notification
            if updated.readAt == nil { updated.readAt = now }
            return updated
        }
        Task { try? await api.markNotificationsRead() }
    }

    /// Notifications grouped by the day they arrived, newest day first.
    var byDay: [(day: Date, items: [UserNotification])] {
        Dictionary(grouping: notifications) {
            Calendar.current.startOfDay(for: $0.createdAt)
        }
        .sorted { $0.key > $1.key }
        .map { (day: $0.key, items: $0.value.sorted { $0.createdAt > $1.createdAt }) }
    }
}
