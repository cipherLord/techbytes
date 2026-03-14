import Foundation

struct WikiFeaturedResponse: Decodable, Sendable {
    let tfa: WikiArticleSummary?
    let mostread: WikiMostRead?
    let news: [WikiNewsItem]?
    let image: WikiImageOfTheDay?

    struct WikiMostRead: Decodable, Sendable {
        let articles: [WikiArticleSummary]
    }
}

struct WikiNewsItem: Decodable, Sendable {
    let story: String?
    let links: [WikiArticleSummary]?
}

struct WikiImageOfTheDay: Decodable, Sendable {
    let title: String?
    let thumbnail: WikiThumbnail?
    let image: WikiThumbnail?
    let description: WikiImageDescription?

    struct WikiImageDescription: Decodable, Sendable {
        let text: String?
    }
}

struct WikiArticleSummary: Decodable, Sendable {
    let titles: Titles?
    let pageid: Int?
    let extract: String?
    let extractHtml: String?
    let description: String?
    let thumbnail: WikiThumbnail?
    let contentUrls: ContentUrls?
    let lang: String?
    let views: Int?

    struct Titles: Decodable, Sendable {
        let canonical: String?
        let normalized: String?
        let display: String?
    }

    struct ContentUrls: Decodable, Sendable {
        let desktop: DesktopUrls?
        struct DesktopUrls: Decodable, Sendable {
            let page: String?
        }
    }

    enum CodingKeys: String, CodingKey {
        case titles, pageid, extract, description, thumbnail, contentUrls, lang, views
        case extractHtml = "extract_html"
    }
}

struct WikiThumbnail: Decodable, Sendable {
    let source: String
    let width: Int
    let height: Int
}

struct WikiRandomResponse: Decodable, Sendable {
    let query: QueryResult

    struct QueryResult: Decodable, Sendable {
        let random: [RandomPage]
    }

    struct RandomPage: Decodable, Sendable {
        let id: Int
        let title: String
    }
}

struct WikiSearchResponse: Decodable, Sendable {
    let query: SearchQuery?
    let `continue`: SearchContinue?

    struct SearchQuery: Decodable, Sendable {
        let search: [SearchResult]?
    }

    struct SearchResult: Decodable, Sendable {
        let title: String
        let pageid: Int
        let snippet: String?
    }

    struct SearchContinue: Decodable, Sendable {
        let sroffset: Int?
    }
}

final class WikipediaService {
    static let shared = WikipediaService()
    private let network = NetworkManager.shared
    private let baseURL = "https://en.wikipedia.org/api/rest_v1"
    private let mediaWikiURL = "https://en.wikipedia.org/w/api.php"

    private init() {}

    func fetchFeaturedContent(date: Date = Date(), ignoreCache: Bool = false) async throws -> WikiFeaturedResponse {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        let dateStr = formatter.string(from: date)
        guard let url = URL(string: "\(baseURL)/feed/featured/\(dateStr)") else {
            throw NetworkError.invalidURL
        }
        return try await network.fetchWikipedia(url, as: WikiFeaturedResponse.self, ignoreCache: ignoreCache)
    }

    func fetchRandomArticles(count: Int = 8, ignoreCache: Bool = false) async throws -> [WikiArticleSummary] {
        guard let url = URL(string: "\(mediaWikiURL)?action=query&list=random&rnlimit=\(count)&rnnamespace=0&format=json") else {
            throw NetworkError.invalidURL
        }
        let randomResponse = try await network.fetchWikipedia(url, as: WikiRandomResponse.self, ignoreCache: ignoreCache)

        return await withTaskGroup(of: WikiArticleSummary?.self, returning: [WikiArticleSummary].self) { group in
            for page in randomResponse.query.random {
                group.addTask {
                    guard !Task.isCancelled else { return nil }
                    return try? await self.fetchArticleSummary(title: page.title)
                }
            }
            var summaries: [WikiArticleSummary] = []
            for await summary in group {
                if let summary { summaries.append(summary) }
            }
            return summaries
        }
    }

    func searchArticles(query: String, limit: Int = 10, offset: Int = 0) async throws -> (summaries: [WikiArticleSummary], nextOffset: Int?) {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "\(mediaWikiURL)?action=query&list=search&srsearch=\(encoded)&srlimit=\(limit)&sroffset=\(offset)&format=json") else {
            throw NetworkError.invalidURL
        }
        let searchResponse = try await network.fetchWikipedia(url, as: WikiSearchResponse.self, ignoreCache: true)
        guard let results = searchResponse.query?.search, !results.isEmpty else {
            return ([], nil)
        }

        let summaries = await withTaskGroup(of: (Int, WikiArticleSummary?).self, returning: [WikiArticleSummary].self) { group in
            for (index, result) in results.enumerated() {
                group.addTask {
                    guard !Task.isCancelled else { return (index, nil) }
                    return (index, try? await self.fetchArticleSummary(title: result.title))
                }
            }
            var indexed: [(Int, WikiArticleSummary)] = []
            for await (index, summary) in group {
                if let summary { indexed.append((index, summary)) }
            }
            return indexed.sorted { $0.0 < $1.0 }.map(\.1)
        }

        return (summaries, searchResponse.continue?.sroffset)
    }

    func fetchArticleSummary(title: String) async throws -> WikiArticleSummary {
        let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
        guard let url = URL(string: "\(baseURL)/page/summary/\(encoded)") else {
            throw NetworkError.invalidURL
        }
        return try await network.fetchWikipedia(url, as: WikiArticleSummary.self)
    }

    func fetchFullArticleHTML(title: String) async throws -> String {
        let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title
        guard let url = URL(string: "\(baseURL)/page/mobile-html/\(encoded)") else {
            throw NetworkError.invalidURL
        }
        let data = try await network.fetchWikipediaRaw(url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw NetworkError.noData
        }
        return html
    }

    nonisolated func toArticles(from summaries: [WikiArticleSummary], section: WikipediaSection) -> [Article] {
        summaries.compactMap { summary in
            guard let title = summary.titles?.display ?? summary.titles?.normalized else { return nil }
            let pageURL = summary.contentUrls?.desktop?.page ?? "https://en.wikipedia.org/wiki/\(title)"
            return Article(
                id: "wiki-\(summary.pageid ?? title.hashValue)",
                title: title.strippingHTML,
                summary: summary.extract ?? "",
                articleURL: pageURL,
                imageURL: summary.thumbnail?.source,
                source: .wikipedia,
                section: section.rawValue,
                publishDate: Date(),
                topics: extractTopics(from: summary)
            )
        }
    }

    nonisolated func toArticles(from newsItems: [WikiNewsItem]) -> [Article] {
        newsItems.compactMap { item in
            guard let firstLink = item.links?.first,
                  let title = firstLink.titles?.display ?? firstLink.titles?.normalized else { return nil }
            let pageURL = firstLink.contentUrls?.desktop?.page ?? "https://en.wikipedia.org/wiki/\(title)"
            return Article(
                id: "wiki-news-\(firstLink.pageid ?? title.hashValue)",
                title: title.strippingHTML,
                summary: item.story?.strippingHTML ?? firstLink.extract ?? "",
                articleURL: pageURL,
                imageURL: firstLink.thumbnail?.source,
                source: .wikipedia,
                section: WikipediaSection.featured.rawValue,
                publishDate: Date(),
                topics: extractTopics(from: firstLink)
            )
        }
    }

    private nonisolated func extractTopics(from summary: WikiArticleSummary) -> [String] {
        var topics: [String] = []
        let text = ((summary.extract ?? "") + " " + (summary.description ?? "")).lowercased()
        for (name, keywords) in UserTopic.predefined {
            if keywords.contains(where: { text.contains($0.lowercased()) }) {
                topics.append(name)
            }
        }
        return topics
    }
}
