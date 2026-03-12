import SwiftUI

extension Date {
    nonisolated var timeAgoDisplay: String {
        let interval = -timeIntervalSinceNow
        switch interval {
        case ..<60: return "just now"
        case ..<3600: return "\(Int(interval / 60))m ago"
        case ..<86400: return "\(Int(interval / 3600))h ago"
        case ..<604800: return "\(Int(interval / 86400))d ago"
        default: return formatted(.dateTime.month(.abbreviated).day())
        }
    }

    nonisolated static func fromUnixTimestamp(_ ts: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(ts))
    }
}

extension String {
    nonisolated var strippingHTML: String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated var domainFromURL: String? {
        guard let url = URL(string: self),
              let host = url.host else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

extension View {
    func cardStyle() -> some View {
        self
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    func surfaceStyle() -> some View {
        self
            .background(Color.surfaceBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    func fadeSlideIn(index: Int, appeared: Bool) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 24)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.8)
                    .delay(Double(min(index, 8)) * 0.06),
                value: appeared
            )
    }

    func cascadeIn(delay: Double, appeared: Bool) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.82).delay(delay),
                value: appeared
            )
    }
}

extension Int {
    nonisolated var abbreviated: String {
        switch self {
        case ..<1_000: return "\(self)"
        case ..<1_000_000: return String(format: "%.1fK", Double(self) / 1_000)
        default: return String(format: "%.1fM", Double(self) / 1_000_000)
        }
    }
}
