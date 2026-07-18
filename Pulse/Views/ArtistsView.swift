import SwiftUI

struct ArtistsView: View {
    @EnvironmentObject private var artists: ArtistStore

    /// Contact-book alphabet rail only kicks in past 20 artists.
    private var useIndex: Bool { artists.tracked.count > 20 }

    private var sections: [(letter: String, artists: [UserArtist])] {
        Dictionary(grouping: artists.tracked) { entry in
            let first = entry.artists.name.uppercased().first.map(String.init) ?? "#"
            return first.rangeOfCharacter(from: .letters) != nil ? first : "#"
        }
        .sorted { $0.key < $1.key }
        .map { (letter: $0.key, artists: $0.value) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("ARTISTS")
                        .font(.mono(16, .bold))
                        .kerning(3)
                        .foregroundStyle(Color.pulseAccent)
                    Spacer()
                    Text("\(artists.tracked.count) TRACKED")
                        .font(.mono(10))
                        .kerning(1)
                        .foregroundStyle(Color.pulseTextMuted)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

                ScrollViewReader { proxy in
                    ZStack(alignment: .trailing) {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 10) {
                                syncingRows

                                if artists.isLoading && artists.tracked.isEmpty {
                                    LoadingState()
                                } else if artists.tracked.isEmpty && artists.syncing.isEmpty {
                                    EmptyState(
                                        icon: "person.2",
                                        message: "No artists yet — find some in search"
                                    )
                                } else if useIndex {
                                    ForEach(sections, id: \.letter) { section in
                                        PulseSectionHeader(text: section.letter)
                                            .padding(.top, 8)
                                            .id(section.letter)
                                        ForEach(section.artists) { entry in
                                            artistRow(entry)
                                        }
                                    }
                                } else {
                                    ForEach(artists.tracked) { entry in
                                        artistRow(entry)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.trailing, useIndex ? 18 : 0)
                            .padding(.bottom, 24)
                        }
                        .refreshable { await artists.load() }

                        if useIndex {
                            AlphabetIndex(letters: sections.map(\.letter)) { letter in
                                withAnimation { proxy.scrollTo(letter, anchor: .top) }
                            }
                        }
                    }
                }
            }
            .background(Color.pulseBg)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    @ViewBuilder
    private var syncingRows: some View {
        ForEach(artists.syncing) { pending in
            PulseCard {
                HStack(spacing: 12) {
                    ArtistAvatar(url: pending.imageUrl, name: pending.name)
                    Text(pending.name)
                        .font(.mono(14, .bold))
                        .foregroundStyle(.white)
                    Spacer()
                    // Sits where the ACTIVE/INACTIVE pill normally goes
                    HStack(spacing: 5) {
                        ProgressView()
                            .tint(Color.pulseAmber)
                            .scaleEffect(0.6)
                            .frame(width: 10, height: 10)
                        Text("SYNCING")
                            .font(.mono(9, .bold))
                            .kerning(1)
                            .foregroundStyle(Color.pulseAmber)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.pulseAmber, lineWidth: 1)
                    )
                }
            }
        }
    }

    private func artistRow(_ entry: UserArtist) -> some View {
        NavigationLink {
            ArtistDetailView(entry: entry)
        } label: {
            PulseCard {
                HStack(spacing: 12) {
                    ArtistAvatar(url: entry.artists.imageUrl, name: entry.artists.name)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.artists.name)
                            .font(.mono(14, .bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        if let genres = entry.artists.genres, !genres.isEmpty {
                            Text(genres.prefix(3).joined(separator: " · ").lowercased())
                                .font(.mono(10))
                                .foregroundStyle(Color.pulseTextMuted)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    StatusPill(active: entry.isActive)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                Task { await artists.untrack(entry.artistId) }
            } label: {
                Label("Untrack", systemImage: "person.badge.minus")
            }
        }
    }
}

struct AlphabetIndex: View {
    let letters: [String]
    let onTap: (String) -> Void

    var body: some View {
        VStack(spacing: 3) {
            ForEach(letters, id: \.self) { letter in
                Text(letter)
                    .font(.mono(9, .bold))
                    .foregroundStyle(Color.pulseAccent)
                    .frame(width: 16, height: 14)
                    .contentShape(Rectangle())
                    .onTapGesture { onTap(letter) }
            }
        }
        .padding(.trailing, 2)
    }
}
