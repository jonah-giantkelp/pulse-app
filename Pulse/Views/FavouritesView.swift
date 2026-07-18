import SwiftUI

struct FavouritesView: View {
    @EnvironmentObject private var favourites: FavouritesStore

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("LIKED EVENTS")
                    .font(.mono(16, .bold))
                    .kerning(3)
                    .foregroundStyle(Color.pulseAccent)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if favourites.isLoading {
                        LoadingState()
                    } else if favourites.events.isEmpty {
                        EmptyState(icon: "heart", message: "No liked events yet")
                    } else {
                        ForEach(favourites.events) { event in
                            EventCard(event: event)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .refreshable { await favourites.load() }
        }
    }
}
