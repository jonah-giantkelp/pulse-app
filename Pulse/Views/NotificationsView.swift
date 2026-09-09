import SwiftUI

/// The bell's sheet — new-event announcements in the order they arrived,
/// day-grouped, each row the announced event. Opening marks everything read;
/// rows that were unread at open keep their accent dot until the next visit.
struct NotificationsView: View {
    @EnvironmentObject private var store: NotificationStore
    @Binding var isPresented: Bool

    @State private var unreadAtOpen: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 12)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if store.isLoading {
                        LoadingState()
                    } else if store.notifications.isEmpty {
                        EmptyState(icon: "bell", message: "No new events")
                    } else {
                        ForEach(store.byDay, id: \.day) { group in
                            PulseSectionHeader(text: dayLabel(group.day))
                                .padding(.top, 10)
                            ForEach(group.items) { notification in
                                row(notification)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color.pulseSurface.ignoresSafeArea())
        .task {
            // Refresh before marking read — the store only loads at app
            // launch otherwise, so anything that arrived since would be
            // invisible until the next cold start.
            await store.load()
            unreadAtOpen = Set(
                store.notifications.filter { $0.readAt == nil }.map(\.id)
            )
            store.markAllRead()
        }
    }

    private var header: some View {
        HStack {
            Text("NOTIFICATIONS")
                .font(.mono(13, .bold))
                .kerning(2)
                .foregroundStyle(.white)
            Spacer()
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.pulseTextMuted)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func row(_ notification: UserNotification) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.pulseAccent)
                .frame(width: 6, height: 6)
                .opacity(unreadAtOpen.contains(notification.id) ? 1 : 0)
            EventCard(event: notification.event)
        }
    }

    private func dayLabel(_ day: Date) -> String {
        if Calendar.current.isDateInToday(day) { return "TODAY" }
        if Calendar.current.isDateInYesterday(day) { return "YESTERDAY" }
        return PulseFormat.day(day)
    }
}
