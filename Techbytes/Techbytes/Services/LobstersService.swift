import Foundation

struct LobstersItem: Decodable, Sendable {
    let short_id: String
    let created_at: String
    let title: String
    let url: String
    let score: Int
    let comment_count: Int
    let description: String
    let description_plain: String
    let submitter_user: String
    let tags: [String]
    let comments_url: String
}

final class LobstersService {
    static let shared = LobstersService()
    private let network = NetworkManager.shared
    private let baseURL = "https://lobste.rs"

    private init() {}

    func fetchStories(section: LobstersSection, ignoreCache: Bool = false) async throws -> [Article] {
        let endpoint: String
        switch section {
        case .hottest: endpoint = "hottest.json"
        case .newest: endpoint = "newest.json"
        }
        
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            throw NetworkError.invalidURL
        }
        
        let items = try await network.fetchLobsters(url, as: [LobstersItem].self, ignoreCache: ignoreCache)
        
        return items.compactMap { toArticle(from: $0, section: section) }
    }

    private func toArticle(from item: LobstersItem, section: LobstersSection) -> Article? {
        let articleURL = item.url.isEmpty ? item.comments_url : item.url
        
        let summary: String
        if !item.description_plain.isEmpty {
            summary = item.description_plain
        } else if !item.description.isEmpty {
            summary = item.description.strippingHTML
        } else if let urlDomain = articleURL.domainFromURL {
            summary = urlDomain
        } else {
            summary = ""
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let publishDate = formatter.date(from: item.created_at) ?? ISO8601DateFormatter().date(from: item.created_at)
        
        return Article(
            id: "lobsters-\(item.short_id)",
            title: item.title,
            summary: summary,
            articleURL: articleURL,
            source: .lobsters,
            section: section.rawValue,
            author: item.submitter_user,
            publishDate: publishDate,
            score: item.score,
            commentCount: item.comment_count,
            topics: item.tags
        )
    }
}
