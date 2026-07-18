import SwiftUI

enum PulseTab: String, CaseIterable {
    case concerts = "CONCERTS"
    case favourites = "LIKED"
    case artists = "ARTISTS"
    case search = "SEARCH"
    case settings = "SETTINGS"

    var icon: String {
        switch self {
        case .concerts: "waveform"
        case .favourites: "heart"
        case .artists: "person.2"
        case .search: "magnifyingglass"
        case .settings: "gearshape"
        }
    }
}

/// Cross-tab navigation: lets any screen switch tabs and hand the Search tab
/// a query (e.g. tapping an untracked lineup artist on an event).
@MainActor
final class AppRouter: ObservableObject {
    @Published var tab: PulseTab = .concerts
    @Published var pendingSearch: String?

    func searchFor(_ name: String) {
        pendingSearch = name
        tab = .search
    }
}

struct MainTabView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var artists: ArtistStore
    @EnvironmentObject private var events: EventStore
    @EnvironmentObject private var favourites: FavouritesStore

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch router.tab {
                case .concerts: ConcertsView()
                case .favourites: FavouritesView()
                case .artists: ArtistsView()
                case .search: SearchView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            PulseTabBar(selected: $router.tab)
        }
        .background(Color.pulseBg.ignoresSafeArea())
        .task {
            async let a: Void = artists.load()
            async let e: Void = events.load()
            async let f: Void = favourites.load()
            _ = await (a, e, f)
        }
    }
}

struct PulseTabBar: View {
    @Binding var selected: PulseTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PulseTab.allCases, id: \.self) { tab in
                Button {
                    selected = tab
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 17, weight: .regular))
                        Text(tab.rawValue)
                            .font(.mono(8))
                            .kerning(0.5)
                    }
                    .foregroundStyle(selected == tab ? Color.pulseAccent : Color.pulseTextFaint)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 2)
        .background(
            Color.pulseSurface
                .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.pulseBorder), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}
