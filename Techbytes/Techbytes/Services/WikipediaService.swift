import Foundation

struct WikiFeaturedResponse: Decodable, Sendable {
    let tfa: WikiArticleSummary?
    let mostread: WikiMostRead?
    let onthisday: [WikiOnThisDay]?

    struct WikiMostRead: Decodable, Sendable {
        let articles: [WikiArticleSummary]
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

struct WikiOnThisDay: Decodable, Sendable {
    let text: String?
    let year: Int?
    let pages: [WikiArticleSummary]?
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

    func fetchOnThisDay(type: String = "all", date: Date = Date(), ignoreCache: Bool = false) async throws -> [WikiOnThisDay] {
        let calendar = Calendar.current
        let month = String(format: "%02d", calendar.component(.month, from: date))
        let day = String(format: "%02d", calendar.component(.day, from: date))
        guard let url = URL(string: "\(baseURL)/feed/onthisday/\(type)/\(month)/\(day)") else {
            throw NetworkError.invalidURL
        }
        struct Response: Decodable {
            let events: [WikiOnThisDay]?
            let births: [WikiOnThisDay]?
            let deaths: [WikiOnThisDay]?
            let selected: [WikiOnThisDay]?
        }
        let response = try await network.fetchWikipedia(url, as: Response.self, ignoreCache: ignoreCache)
        var results: [WikiOnThisDay] = []
        if let selected = response.selected { results.append(contentsOf: selected.prefix(10)) }
        if let events = response.events { results.append(contentsOf: events.prefix(5)) }
        return results
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

    nonisolated func toArticles(from events: [WikiOnThisDay]) -> [Article] {
        events.compactMap { event in
            guard let text = event.text else { return nil }
            let yearStr = event.year.map { "\($0): " } ?? ""
            let firstPage = event.pages?.first
            let pageURL = firstPage?.contentUrls?.desktop?.page ?? ""
            let id = "wiki-otd-\(event.year ?? 0)-\(text.prefix(30).hashValue)"
            return Article(
                id: id,
                title: "\(yearStr)\(text)".strippingHTML,
                summary: firstPage?.extract ?? text.strippingHTML,
                articleURL: pageURL,
                imageURL: firstPage?.thumbnail?.source,
                source: .wikipedia,
                section: WikipediaSection.onThisDay.rawValue,
                publishDate: Date(),
                topics: firstPage.flatMap { extractTopics(from: $0) } ?? []
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
