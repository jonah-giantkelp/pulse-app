import Foundation

// Decoded with .convertFromSnakeCase — property names mirror API fields.

struct ArtistSearchResult: Codable, Identifiable, Hashable {
    var id: String { musicbrainzId }
    let musicbrainzId: String
    let name: String
    let disambiguation: String?
    let country: String?
    let tags: [String]?
    let genres: [String]?
    let imageUrl: String?
}

struct Artist: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let musicbrainzId: String?
    let spotifyId: String?
    let instagramHandle: String?
    let twitterHandle: String?
    let websiteUrl: String?
    let diceSlug: String?
    let raId: String?
    let genres: [String]?
    let imageUrl: String?
    let active: Bool?

    var isActive: Bool { active ?? true }
}

struct UserArtist: Codable, Identifiable, Hashable {
    var id: UUID { artistId }
    let artistId: UUID
    let city: String?
    let notify: Bool?
    let hasUpcoming: Bool?
    let artists: Artist

    /// ACTIVE = has at least one upcoming gig, nothing else.
    var isActive: Bool { hasUpcoming ?? false }
}

struct EventArtist: Codable, Hashable {
    let artistId: UUID
    let name: String
    let imageUrl: String?
    let billing: String?
}

struct EventImage: Codable, Hashable {
    let imageUrl: String
    let imageType: String?
}

struct TicketLink: Codable, Hashable {
    let source: String
    let url: String
    let priceMin: Double?
    let priceMax: Double?
    let currency: String?
}

struct EventDetail: Codable, Hashable {
    let description: String?
    let lineup: [String]?
    let doorsOpen: String?
    let ageRestriction: String?
    let status: String?
    let venueAddress: String?
    let genre: String?
}

struct EventSocialPost: Codable, Hashable {
    let platform: String
    let caption: String?
    let mediaUrl: String?
    let postedAt: Date?
}

struct Event: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let date: Date
    let venue: String?
    let city: String?
    let country: String?
    let source: String?
    let time: String?
    let ticketUrl: String?
    let artistBilling: String?
    let artists: [EventArtist]?
    let images: [EventImage]?
    let ticketLinks: [TicketLink]?
    let detail: EventDetail?
    let socialPost: EventSocialPost?

    var primaryArtist: EventArtist? { artists?.first }

    var locationLine: String {
        [venue, city, country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var bestTicketURL: URL? {
        if let link = ticketLinks?.first { return URL(string: link.url) }
        if let url = ticketUrl { return URL(string: url) }
        return nil
    }

    var priceLabel: String? {
        ticketLinks?.compactMap { PulseFormat.price($0) }.first
    }
}

struct EmailPreferences: Codable {
    var email: String?
    var recipients: [String]?
    var digestEnabled: Bool
    var pushEnabled: Bool?
    var defaultCities: [String]
    var defaultCountries: [String]
}

struct AddArtistResponse: Codable {
    let artistId: UUID?
    let status: String?
    let message: String?
    let needsReview: [String]?
}

struct StatusResponse: Codable {
    let status: String?
}
