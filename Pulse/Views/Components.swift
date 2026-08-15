import SwiftUI

// MARK: - Pulse mark (same geometry as the app icon)

struct PulseMark: Shape {
    func path(in rect: CGRect) -> Path {
        // Normalised from the 1024pt icon artwork
        let pts: [(CGFloat, CGFloat)] = [
            (100, 512), (246, 512),
            (296, 478), (348, 548),
            (404, 424), (462, 628),
            (518, 286), (576, 736),
            (634, 424), (690, 572),
            (742, 486), (788, 512),
            (924, 512),
        ]
        var path = Path()
        let scaleX = rect.width / 1024
        let scaleY = rect.height / 1024
        path.move(to: CGPoint(x: pts[0].0 * scaleX, y: pts[0].1 * scaleY))
        for p in pts.dropFirst() {
            path.addLine(to: CGPoint(x: p.0 * scaleX, y: p.1 * scaleY))
        }
        return path
    }
}

// MARK: - Wordmark

struct PulseWordmark: View {
    var size: CGFloat = 24
    var text: String = "PULSE"
    var kernScale: CGFloat = 0.6

    var body: some View {
        // Words rendered separately: kerning a space doubles the gap (kern + space width).
        HStack(spacing: size * 0.25) {
            ForEach(Array(text.split(separator: " ").enumerated()), id: \.offset) { _, word in
                Text(word)
                    .font(.mono(size, .bold))
                    .kerning(size * kernScale)
            }
        }
        .foregroundStyle(Color.pulseAccent)
        .padding(.leading, size * kernScale) // optically balance the trailing kern
    }
}

// MARK: - Pills & badges

struct StatusPill: View {
    let active: Bool

    var body: some View {
        Text(active ? "ACTIVE" : "INACTIVE")
            .font(.mono(9, .bold))
            .kerning(1)
            .foregroundStyle(active ? Color.pulseAccent : Color.pulseTextFaint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(active ? Color.pulseAccent : Color.pulseBorderLight, lineWidth: 1)
            )
    }
}

struct SourceBadge: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.mono(9))
            .foregroundStyle(Color.pulseTextMuted)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.pulseBorderLight, lineWidth: 1)
            )
    }
}

struct DateBadge: View {
    let text: String

    init(date: Date) { text = PulseFormat.day(date) }
    init(text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.mono(11, .bold))
            .kerning(1)
            .foregroundStyle(Color.pulseAccent)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.pulseAccent, lineWidth: 1)
            )
    }
}

struct TagChip: View {
    let text: String

    var body: some View {
        Text(text.lowercased())
            .font(.mono(10))
            .foregroundStyle(Color.pulseTextSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.pulseCard)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.pulseBorder, lineWidth: 1)
            )
    }
}

// MARK: - Section header

struct PulseSectionHeader: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.mono(12, .bold))
            .kerning(2)
            .foregroundStyle(Color.pulseAccent)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Buttons

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.mono(13, .bold))
            .kerning(1.5)
            .foregroundStyle(Color.pulseBg)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(Color.pulseAccent)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct OutlineButtonStyle: ButtonStyle {
    var color: Color = .pulseAccent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.mono(12, .bold))
            .kerning(1.5)
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(color, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - Cards

struct PulseCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.pulseCard)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.pulseBorder, lineWidth: 1)
            )
    }
}

// MARK: - Avatar

struct ArtistAvatar: View {
    let url: String?
    let name: String
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let url, let parsed = URL(string: url) {
                AsyncImage(url: parsed) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    initialView
                }
            } else {
                initialView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.pulseBorderLight, lineWidth: 1))
    }

    private var initialView: some View {
        ZStack {
            Color.pulseCard
            Text(String(name.prefix(1)).uppercased())
                .font(.mono(size * 0.4, .bold))
                .foregroundStyle(Color.pulseTextMuted)
        }
    }
}

// MARK: - Text field

struct PulseTextField: View {
    let placeholder: String
    @Binding var text: String
    var secure = false
    var keyboard: UIKeyboardType = .default
    var compact = false

    private var fontSize: CGFloat { compact ? 12 : 14 }

    var body: some View {
        Group {
            if secure {
                SecureField("", text: $text, prompt: prompt)
            } else {
                TextField("", text: $text, prompt: prompt)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
        .font(.mono(fontSize))
        .foregroundStyle(.white)
        .padding(compact ? 8 : 12)
        .background(Color.pulseSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.pulseBorderLight, lineWidth: 1)
        )
    }

    private var prompt: Text {
        Text(placeholder)
            .font(.mono(fontSize))
            .foregroundStyle(Color.pulseTextFaint)
    }
}

// MARK: - Empty / loading states

struct EmptyState: View {
    let icon: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(Color.pulseTextFaint)
            Text(message.uppercased())
                .font(.mono(12))
                .kerning(1)
                .foregroundStyle(Color.pulseTextFaint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

struct LoadingState: View {
    var text = "LOADING"

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(Color.pulseAccent)
            Text(text)
                .font(.mono(11))
                .kerning(2)
                .foregroundStyle(Color.pulseTextFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Stacked avatars

struct StackedAvatars: View {
    let artists: [EventArtist]
    var size: CGFloat = 38

    var body: some View {
        HStack(spacing: -size * 0.35) {
            ForEach(Array(artists.prefix(3).enumerated()), id: \.offset) { index, artist in
                ArtistAvatar(url: artist.imageUrl, name: artist.name, size: size)
                    .background(Circle().fill(Color.pulseBg).padding(-2))
                    .zIndex(Double(-index))
            }
        }
    }
}

// MARK: - Event card (compact, artist-first — tap for full detail)

struct EventCard: View {
    let event: Event
    /// false on the artist page, where the event matters more than the artist.
    var showArtists = true
    /// false where the date is already given by context (day-grouped lists).
    var showDate = true
    @EnvironmentObject private var favourites: FavouritesStore
    @State private var showDetail = false

    /// "X" / "X, Y" / "X, Y + n more" from the tracked artists on the event.
    private var artistHeadline: String? {
        guard let names = event.artists?.map(\.name), !names.isEmpty else { return nil }
        switch names.count {
        case 1: return names[0]
        case 2: return "\(names[0]), \(names[1])"
        default: return "\(names[0]), \(names[1]) + \(names.count - 2) more"
        }
    }

    var body: some View {
        PulseCard {
            HStack(alignment: .center, spacing: 12) {
                if showArtists, let artists = event.artists, !artists.isEmpty {
                    StackedAvatars(artists: artists)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(showArtists ? (artistHeadline ?? event.title) : event.title)
                        .font(.mono(14, .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.leading)
                    Text(event.locationLine.isEmpty ? "TBA" : event.locationLine)
                        .font(.mono(10))
                        .foregroundStyle(Color.pulseTextFaint)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    Button {
                        favourites.toggle(event)
                    } label: {
                        Image(systemName: favourites.contains(event) ? "heart.fill" : "heart")
                            .font(.system(size: 19))
                            .foregroundStyle(favourites.contains(event) ? Color.pulseAccent : Color.pulseTextFaint)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if showDate {
                        DateBadge(date: event.date)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { showDetail = true }
        .sheet(isPresented: $showDetail) {
            EventDetailView(event: event, isPresented: $showDetail)
        }
    }
}
