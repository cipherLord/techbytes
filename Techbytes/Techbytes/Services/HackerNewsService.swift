import Foundation

struct HNItem: Decodable, Sendable {
    let id: Int
    let type: String?
    let by: String?
    let time: Int?
    let title: String?
    let url: String?
    let score: Int?
    let kids: [Int]?
    let descendants: Int?
    let text: String?
}

final class HackerNewsService {
    static let shared = HackerNewsService()
    private let network = NetworkManager.shared
    private let baseURL = "https://hacker-news.firebaseio.com/v0"

    private init() {}

    func fetchStoryIDs(section: HackerNewsSection, ignoreCache: Bool = false) async throws -> [Int] {
        let endpoint: String
        switch section {
        case .new: endpoint = "newstories"
        case .mostUpvoted: endpoint = "beststories"
        }
        guard let url = URL(string: "\(baseURL)/\(endpoint).json") else {
            throw NetworkError.invalidURL
        }
        return try await network.fetchHackerNews(url, as: [Int].self, ignoreCache: ignoreCache)
    }

    func fetchItem(id: Int) async throws -> HNItem {
        guard let url = URL(string: "\(baseURL)/item/\(id).json") else {
            throw NetworkError.invalidURL
        }
        return try await network.fetchHackerNews(url, as: HNItem.self)
    }

    func fetchStoriesFromIDs(_ ids: [Int], section: HackerNewsSection, sorted: Bool = true) async throws -> [Article] {
        var articles: [Article] = []
        var failCount = 0

        await withTaskGroup(of: HNItem?.self) { group in
            for id in ids {
                group.addTask { [weak self] in
                    guard !Task.isCancelled else { return nil }
                    return try? await self?.fetchItem(id: id)
                }
            }
            for await item in group {
                if let item, let article = toArticle(from: item, section: section) {
                    articles.append(article)
                } else {
                    failCount += 1
                }
            }
        }

        if articles.isEmpty && failCount > 0 && !Task.isCancelled {
            throw NetworkError.noData
        }

        return sorted ? articles.sorted { ($0.score ?? 0) > ($1.score ?? 0) } : articles
    }

    private func toArticle(from item: HNItem, section: HackerNewsSection) -> Article? {
        guard let title = item.title else { return nil }
        let articleURL = item.url ?? "https://news.ycombinator.com/item?id=\(item.id)"
        let summary: String
        if let text = item.text {
            summary = text.strippingHTML
        } else if let urlDomain = item.url?.domainFromURL {
            summary = urlDomain
        } else {
            summary = ""
        }

        return Article(
            id: "hn-\(item.id)",
            title: title,
            summary: summary,
            articleURL: articleURL,
            source: .hackerNews,
            section: section.rawValue,
            author: item.by,
            publishDate: item.time.map { Date.fromUnixTimestamp($0) },
            score: item.score,
            commentCount: item.descendants
        )
    }
}
