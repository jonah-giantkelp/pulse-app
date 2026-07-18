import SwiftUI

struct ArtistDetailView: View {
    let entry: UserArtist

    @EnvironmentObject private var artists: ArtistStore
    @Environment(\.dismiss) private var dismiss

    @State private var localEvents: [Event] = []
    @State private var otherEvents: [Event] = []
    @State private var eventScope: EventScope = .local
    @State private var isLoading = true

    private enum EventScope { case local, other }
    private var scopedEvents: [Event] { eventScope == .local ? localEvents : otherEvents }

    private var artist: Artist { entry.artists }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    ArtistAvatar(url: artist.imageUrl, name: artist.name, size: 72)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(artist.name)
                            .font(.mono(19, .bold))
                            .foregroundStyle(.white)
                        StatusPill(active: entry.isActive)
                    }
                    Spacer()
                }

                if let genres = artist.genres, !genres.isEmpty {
                    FlowChips(items: genres)
                }

                linkChips

                VStack(alignment: .leading, spacing: 12) {
                    PulseSectionHeader(text: "Upcoming")
                    HStack(spacing: 20) {
                        scopeTab("YOUR LOCATIONS", count: localEvents.count, value: .local)
                        scopeTab("OTHER", count: otherEvents.count, value: .other)
                        Spacer()
                    }
                    if isLoading {
                        LoadingState()
                    } else if scopedEvents.isEmpty {
                        Text(eventScope == .local ? "NO UPCOMING EVENTS IN YOUR LOCATIONS" : "NO UPCOMING EVENTS ELSEWHERE")
                            .font(.mono(11))
                            .kerning(1)
                            .foregroundStyle(Color.pulseTextFaint)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(scopedEvents) { event in
                            EventCard(event: event, showArtists: false)
                        }
                    }
                }

                Button {
                    Task {
                        await artists.untrack(entry.artistId)
                        dismiss()
                    }
                } label: {
                    Text("UNTRACK ARTIST")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(OutlineButtonStyle(color: .pulseDanger))
                .padding(.top, 12)
            }
            .padding(16)
        }
        .background(Color.pulseBg)
        .task { await loadDetail() }
    }

    @ViewBuilder
    private var linkChips: some View {
        let links: [(String, URL?)] = [
            ("SPOTIFY", artist.spotifyId.flatMap { URL(string: "https://open.spotify.com/artist/\($0)") }),
            ("INSTAGRAM", artist.instagramHandle.flatMap { URL(string: "https://instagram.com/\($0)") }),
            ("X", artist.twitterHandle.flatMap { URL(string: "https://x.com/\($0)") }),
            ("WEB", artist.websiteUrl.flatMap { URL(string: $0) }),
        ]
        let available = links.compactMap { pair in pair.1.map { (pair.0, $0) } }
        if !available.isEmpty {
            HStack(spacing: 8) {
                ForEach(available, id: \.0) { label, url in
                    Link(destination: url) {
                        Text(label)
                            .font(.mono(10, .bold))
                            .kerning(1)
                            .foregroundStyle(Color.pulseTextSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.pulseBorderLight, lineWidth: 1)
                            )
                    }
                }
            }
        }
    }

    private func scopeTab(_ title: String, count: Int, value: EventScope) -> some View {
        Button {
            eventScope = value
        } label: {
            VStack(spacing: 5) {
                Text("\(title) (\(count))")
                    .font(.mono(11, .bold))
                    .kerning(1)
                    .foregroundStyle(eventScope == value ? Color.pulseAccent : Color.pulseTextFaint)
                Rectangle()
                    .fill(eventScope == value ? Color.pulseAccent : Color.clear)
                    .frame(height: 2)
            }
            .fixedSize()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func loadDetail() async {
        isLoading = true
        defer { isLoading = false }
        (localEvents, otherEvents) = await artists.detailEvents(for: entry.artistId)
    }
}

struct FlowChips: View {
    let items: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    TagChip(text: item)
                }
            }
        }
    }
}
