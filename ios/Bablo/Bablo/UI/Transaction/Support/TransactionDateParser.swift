import Foundation

enum TransactionDateParser {
    static func parsedDate(_ raw: String) -> Date? {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = Calendar.bablo.timeZone

        if raw.count >= 10 {
            parser.dateFormat = "yyyy-MM-dd"
            if let date = parser.date(from: String(raw.prefix(10))) { return date }
        }

        parser.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        if let date = parser.date(from: raw) { return date }

        parser.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let date = parser.date(from: raw) { return date }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return date }

        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: raw)
    }

    static func parsedDateTime(_ raw: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return date }

        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: raw) { return date }

        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = TimeZone(identifier: "UTC")
        parser.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        if let date = parser.date(from: raw) { return date }

        parser.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let date = parser.date(from: raw) { return date }

        parser.dateFormat = "yyyy-MM-dd"
        return parser.date(from: raw)
    }

    static func formatDate(_ raw: String, style: DateFormatter.Style) -> String {
        guard let date = parsedDate(raw) else { return raw }
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    static func formatDateTime(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
