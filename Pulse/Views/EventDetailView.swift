import SwiftUI

struct EventDetailView: View {
    let event: Event
    // The presenting card's sheet flag — environment dismiss is unreliable
    // when the presenter sits inside a NavigationStack push.
    @Binding var isPresented: Bool

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var artists: ArtistStore
    @EnvironmentObject private var favourites: FavouritesStore

    @State private var showFullLineup = false

    private var tracked: [EventArtist] { event.artists ?? [] }

    /// Lineup names from the source (RA/DICE) that aren't tracked artists.
    private var untrackedLineup: [String] {
        let trackedNames = Set(tracked.map { $0.name.lowercased() })
        return (event.detail?.lineup ?? []).filter { !trackedNames.contains($0.lowercased()) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                poster
                titleBlock
                infoBlock

                if let description = event.detail?.description, !description.isEmpty {
                    sectionBlock("About") {
                        Text(description)
                            .font(.mono(12))
                            .foregroundStyle(Color.pulseTextSecondary)
                            .lineSpacing(4)
                    }
                }

                socialBlock
                ticketsBlock
                lineupBlock
            }
            .padding(16)
        }
        .background(Color.pulseSurface)
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Button {
                isPresented = false
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.pulseAccent)
                    .frame(width: 32, height: 32, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Spacer()
            Text("EVENT")
                .font(.mono(11, .bold))
                .kerning(2)
                .foregroundStyle(Color.pulseTextMuted)
            Spacer()
            Button {
                favourites.toggle(event)
            } label: {
                Image(systemName: favourites.contains(event) ? "heart.fill" : "heart")
                    .font(.system(size: 17))
                    .foregroundStyle(favourites.contains(event) ? Color.pulseAccent : Color.pulseTextFaint)
                    .frame(width: 32, height: 32, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var poster: some View {
        if let image = event.images?.first, let url = URL(string: image.imageUrl) {
            AsyncImage(url: url) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Color.pulseCard
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.pulseBorder, lineWidth: 1)
            )
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            // The detail view frames around the event itself; the list frames
            // around the artists.
            Text(event.title)
                .font(.mono(19, .bold))
                .foregroundStyle(.white)

            if !tracked.isEmpty {
                HStack(spacing: 8) {
                    StackedAvatars(artists: tracked, size: 26)
                    Text(tracked.map(\.name).joined(separator: ", "))
                        .font(.mono(12))
                        .foregroundStyle(Color.pulseTextSecondary)
                        .lineLimit(2)
                }
            }

            HStack(spacing: 8) {
                DateBadge(date: event.date)
                if let time = event.time {
                    Text(time)
                        .font(.mono(12, .bold))
                        .foregroundStyle(.white)
                }
                if let status = event.detail?.status,
                   ["sold-out", "cancelled", "offsale"].contains(status.lowercased()) {
                    Text(status.uppercased())
                        .font(.mono(9, .bold))
                        .kerning(1)
                        .foregroundStyle(Color.pulseDanger)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.pulseDanger, lineWidth: 1)
                        )
                }
                if let source = event.source, !["social_ai", "concerts_tracker"].contains(source) {
                    SourceBadge(text: source)
                }
            }
        }
    }

    private var infoBlock: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: 10) {
                infoRow("VENUE", event.locationLine.isEmpty ? "TBA" : event.locationLine)
                if let address = event.detail?.venueAddress {
                    infoRow("ADDRESS", address)
                }
                if let doors = event.detail?.doorsOpen {
                    infoRow("DOORS", PulseFormat.time(doors))
                }
                if let age = event.detail?.ageRestriction {
                    infoRow("AGE", age)
                }
                if let genre = event.detail?.genre {
                    infoRow("GENRE", genre)
                }
            }
        }
    }

    /// Label column + value — structure without icons.
    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.mono(9, .bold))
                .kerning(1)
                .foregroundStyle(Color.pulseTextFaint)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(.mono(11))
                .foregroundStyle(Color.pulseTextSecondary)
        }
    }

    /// Embedded when the event was surfaced from a social post.
    @ViewBuilder
    private var socialBlock: some View {
        if let post = event.socialPost {
            PulseCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            PlatformIcon(platform: post.platform)
                            Text("VIA \(post.platform.uppercased())")
                                .font(.mono(9, .bold))
                                .kerning(1)
                                .foregroundStyle(Color.pulseTextMuted)
                            Spacer()
                            if let at = post.postedAt {
                                Text(PulseFormat.day(at))
                                    .font(.mono(9))
                                    .foregroundStyle(Color.pulseTextFaint)
                            }
                        }
                        if let media = post.mediaUrl, let url = URL(string: media) {
                            AsyncImage(url: url) { img in
                                img.resizable().scaledToFill()
                            } placeholder: {
                                Color.pulseSurface
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.pulseBorder, lineWidth: 1)
                            )
                        }
                        if let caption = post.caption, !caption.isEmpty {
                            Text(caption)
                                .font(.mono(11))
                                .foregroundStyle(Color.pulseTextSecondary)
                                .lineSpacing(3)
                                .lineLimit(8)
                        }
                    }
            }
        }
    }

    @ViewBuilder
    private var ticketsBlock: some View {
        let links = event.realTicketLinks
        if !links.isEmpty {
            sectionBlock("Tickets") {
                VStack(spacing: 8) {
                    ForEach(Array(links.enumerated()), id: \.offset) { _, link in
                        if let url = URL(string: link.url) {
                            Link(destination: url) {
                                HStack {
                                    Text(link.source.uppercased())
                                        .font(.mono(12, .bold))
                                        .kerning(1)
                                        .foregroundStyle(Color.pulseAccent)
                                    Spacer()
                                    Text(PulseFormat.price(link) ?? "VIEW")
                                        .font(.mono(12, .bold))
                                        .foregroundStyle(.white)
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Color.pulseAccent)
                                }
                                .padding(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.pulseAccent, lineWidth: 1)
                                )
                            }
                        }
                    }
                }
            }
        } else if let url = event.bestTicketURL {
            Link(destination: url) {
                Text("TICKETS →")
                    .font(.mono(13, .bold))
                    .kerning(1.5)
                    .foregroundStyle(Color.pulseBg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.pulseAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    @ViewBuilder
    private var lineupBlock: some View {
        // A one-artist bill isn't a lineup
        if tracked.count + untrackedLineup.count >= 2 {
            sectionBlock("Lineup") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(tracked, id: \.artistId) { artist in
                        HStack(spacing: 10) {
                            ArtistAvatar(url: artist.imageUrl, name: artist.name, size: 32)
                            Text(artist.name)
                                .font(.mono(13, .bold))
                                .foregroundStyle(.white)
                            if let billing = artist.billing {
                                TagChip(text: billing)
                            }
                            Spacer()
                            Text("TRACKED ✓")
                                .font(.mono(9, .bold))
                                .kerning(1)
                                .foregroundStyle(Color.pulseAccent)
                        }
                    }

                    if !untrackedLineup.isEmpty {
                        Button {
                            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                                showFullLineup.toggle()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(showFullLineup
                                    ? "HIDE FULL LINEUP"
                                    : "FULL LINEUP (\(untrackedLineup.count + tracked.count))")
                                    .font(.mono(10, .bold))
                                    .kerning(1)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                                    .rotationEffect(.degrees(showFullLineup ? 180 : 0))
                            }
                            .foregroundStyle(Color.pulseTextMuted)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 10) {
                            if showFullLineup {
                                ForEach(untrackedLineup, id: \.self) { name in
                                    Button {
                                        router.searchFor(name)
                                        isPresented = false
                                    } label: {
                                        HStack(spacing: 10) {
                                            ArtistAvatar(url: nil, name: name, size: 32)
                                            Text(name)
                                                .font(.mono(13))
                                                .foregroundStyle(Color.pulseTextSecondary)
                                            Spacer()
                                            Image(systemName: "magnifyingglass")
                                                .font(.system(size: 12))
                                                .foregroundStyle(Color.pulseTextFaint)
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .clipped() // rows unfold from under the toggle, no overflow flash
                    }
                }
            }
        }
    }

    private func sectionBlock(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            PulseSectionHeader(text: title)
            content()
        }
    }
}

/// Tiny outlined "IG" / "X" glyph matching the badge design.
struct PlatformIcon: View {
    let platform: String

    var body: some View {
        Text(platform.lowercased() == "instagram" ? "IG" : "X")
            .font(.mono(8, .bold))
            .foregroundStyle(Color.pulseTextSecondary)
            .frame(width: 18, height: 18)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.pulseBorderLight, lineWidth: 1)
            )
    }
}
