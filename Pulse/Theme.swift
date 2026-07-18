import SwiftUI

// Palette lifted from the Pulse email digest (mailer/template.py).
extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    static let pulseBg = Color(hex: 0x0A0A0A)
    static let pulseSurface = Color(hex: 0x0D0D0D)
    static let pulseCard = Color(hex: 0x1A1A1A)
    static let pulseBorder = Color(hex: 0x2A2A2A)
    static let pulseBorderLight = Color(hex: 0x3A3A3A)
    // Softened from the email's #C8FF00 — the neon lime was too much in-app.
    static let pulseAccent = Color(hex: 0xA9D65C)
    static let pulseTextSecondary = Color(hex: 0xAAAAAA)
    static let pulseTextMuted = Color(hex: 0x888888)
    static let pulseTextFaint = Color(hex: 0x666666)
    static let pulseDanger = Color(hex: 0xFF5C5C)
}

extension Font {
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

enum PulseFormat {
    static let sectionDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f
    }()

    static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    static func day(_ date: Date) -> String {
        sectionDay.string(from: date).uppercased()
    }

    /// Normalises source time strings — ISO datetimes (DICE) and "17:30:00"
    /// (Skiddle) both come out as "17:30".
    static func time(_ raw: String) -> String {
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: raw) {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return f.string(from: date)
        }
        let noZone = DateFormatter()
        noZone.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let date = noZone.date(from: raw) {
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return f.string(from: date)
        }
        let parts = raw.split(separator: ":")
        if parts.count >= 2 { return "\(parts[0]):\(parts[1])" }
        return raw
    }

    /// "THU–FRI 6–7 AUG" for a same-month run, "SAT 30 AUG – MON 1 SEP" across.
    static func dayRange(_ from: Date, _ to: Date) -> String {
        let calendar = Calendar.current
        let weekday = DateFormatter()
        weekday.dateFormat = "EEE"
        let month = DateFormatter()
        if calendar.isDate(from, equalTo: to, toGranularity: .month) {
            month.dateFormat = "MMM"
            let days = "\(calendar.component(.day, from: from))–\(calendar.component(.day, from: to))"
            return "\(weekday.string(from: from))–\(weekday.string(from: to)) \(days) \(month.string(from: from))".uppercased()
        }
        month.dateFormat = "EEE d MMM"
        return "\(month.string(from: from)) – \(month.string(from: to))".uppercased()
    }

    static func price(_ link: TicketLink) -> String? {
        guard let min = link.priceMin else { return nil }
        if min == 0 { return "FREE" }
        let symbol: String
        switch link.currency {
        case "GBP": symbol = "£"
        case "EUR": symbol = "€"
        case "USD": symbol = "$"
        default: symbol = (link.currency ?? "") + " "
        }
        let fmt = { (v: Double) in v == v.rounded() ? String(Int(v)) : String(format: "%.2f", v) }
        if let max = link.priceMax, max != min {
            return "\(symbol)\(fmt(min))–\(fmt(max))"
        }
        return "\(symbol)\(fmt(min))"
    }
}
