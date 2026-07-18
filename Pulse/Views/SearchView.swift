import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var artists: ArtistStore
    @EnvironmentObject private var router: AppRouter

    @State private var query = ""
    @State private var results: [ArtistSearchResult] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var toast: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Text("SEARCH")
                    .font(.mono(16, .bold))
                    .kerning(3)
                    .foregroundStyle(Color.pulseAccent)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.pulseTextFaint)
                    TextField("", text: $query, prompt: Text("FIND ARTISTS")
                        .font(.mono(14))
                        .foregroundStyle(Color.pulseTextFaint))
                        .font(.mono(14))
                        .foregroundStyle(.white)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .padding(12)
                .background(Color.pulseSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.pulseBorderLight, lineWidth: 1)
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)

            ScrollView {
                LazyVStack(spacing: 10) {
                    if let toast {
                        Text(toast.uppercased())
                            .font(.mono(10, .bold))
                            .kerning(1)
                            .foregroundStyle(Color.pulseBg)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.pulseAccent)
                            .clipShape(Capsule())
                    }

                    if results.isEmpty {
                        if isSearching {
                            LoadingState(text: "SEARCHING")
                        } else if hasSearched {
                            EmptyState(icon: "questionmark", message: "No artists found — try the full name")
                        } else {
                            EmptyState(icon: "magnifyingglass", message: "Search for new artists to track")
                        }
                    } else {
                        ForEach(results) { result in
                            SearchResultCard(result: result, onToast: { toast = $0 })
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .onAppear { consumePendingSearch() }
        .onChange(of: router.pendingSearch) { _, _ in consumePendingSearch() }
        .onChange(of: query) { _, newValue in
            searchTask?.cancel()
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            guard trimmed.count >= 2 else {
                results = []
                hasSearched = false
                isSearching = false
                return
            }
            searchTask = Task {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                await runSearch(trimmed)
            }
        }
    }

    private func consumePendingSearch() {
        guard let pending = router.pendingSearch else { return }
        router.pendingSearch = nil
        query = pending // onChange(of: query) debounce kicks off the search
    }

    private func runSearch(_ q: String) async {
        isSearching = true
        defer { isSearching = false }
        do {
            let found = try await artists.search(query: q)
            guard !Task.isCancelled else { return }
            results = found
            hasSearched = true
        } catch {
            guard !Task.isCancelled else { return }
            results = []
            hasSearched = true
        }
    }
}

struct SearchResultCard: View {
    let result: ArtistSearchResult
    let onToast: (String) -> Void

    @EnvironmentObject private var artists: ArtistStore

    private enum TrackState {
        case idle, syncing, tracked
    }

    private var state: TrackState {
        if artists.trackedMusicbrainzIds.contains(result.musicbrainzId) { return .tracked }
        if artists.syncing.contains(where: { $0.musicbrainzId == result.musicbrainzId }) { return .syncing }
        return .idle
    }

    var body: some View {
        PulseCard {
            HStack(alignment: .top, spacing: 12) {
                ArtistAvatar(url: result.imageUrl, name: result.name, size: 48)

                VStack(alignment: .leading, spacing: 5) {
                    Text(result.name)
                        .font(.mono(14, .bold))
                        .foregroundStyle(.white)
                    if let disambiguation = result.disambiguation, !disambiguation.isEmpty {
                        Text(disambiguation)
                            .font(.mono(11))
                            .foregroundStyle(Color.pulseTextSecondary)
                            .lineLimit(2)
                    }
                    if let country = result.country {
                        Text(country)
                            .font(.mono(10))
                            .foregroundStyle(Color.pulseTextMuted)
                    }
                    let chips = result.tags ?? result.genres ?? []
                    if !chips.isEmpty {
                        FlowChips(items: Array(chips.prefix(4)))
                    }
                }

                Spacer(minLength: 8)

                trackButton
            }
        }
    }

    @ViewBuilder
    private var trackButton: some View {
        switch state {
        case .idle:
            Button {
                Task {
                    if let message = await artists.track(result) {
                        onToast(message)
                    }
                }
            } label: {
                Text("TRACK")
            }
            .buttonStyle(OutlineButtonStyle())
        case .syncing:
            // Same geometry as the TRACK button — it changes colour and buffers
            HStack(spacing: 6) {
                ProgressView()
                    .tint(Color.pulseBg)
                    .scaleEffect(0.7)
                Text("SYNCING")
                    .font(.mono(12, .bold))
                    .kerning(1.5)
            }
            .foregroundStyle(Color.pulseBg)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.pulseAccent.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        case .tracked:
            Text("TRACKED ✓")
                .font(.mono(10, .bold))
                .kerning(1)
                .foregroundStyle(Color.pulseTextFaint)
                .padding(.vertical, 8)
        }
    }
}
