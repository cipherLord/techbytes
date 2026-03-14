import Foundation
import SwiftData

enum ArticleSource: String, Codable {
    case wikipedia
    case hackerNews
    case lobsters
    case techmeme
}

enum WikipediaSection: String, Codable, CaseIterable {
    case featured = "Featured"
    case search = "Search"
    case random = "Random"
}

enum HackerNewsSection: String, Codable, CaseIterable {
    case new = "New"
    case mostUpvoted = "Most upvoted"
}

enum LobstersSection: String, Codable, CaseIterable {
    case hottest = "Hottest"
    case newest = "Newest"
}

enum TechmemeSection: String, Codable, CaseIterable {
    case topNews = "Top News"
}

@Model
final class Article {
    @Attribute(.unique) var id: String
    var title: String
    var summary: String
    var articleURL: String
    var imageURL: String?
    var source: String
    var section: String?
    var author: String?
    var publishDate: Date?
    var score: Int?
    var commentCount: Int?
    var topics: [String]
    var cachedAt: Date
    var isRead: Bool

    init(
        id: String,
        title: String,
        summary: String,
        articleURL: String,
        imageURL: String? = nil,
        source: ArticleSource,
        section: String? = nil,
        author: String? = nil,
        publishDate: Date? = nil,
        score: Int? = nil,
        commentCount: Int? = nil,
        topics: [String] = [],
        isRead: Bool = false
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.articleURL = articleURL
        self.imageURL = imageURL
        self.source = source.rawValue
        self.section = section
        self.author = author
        self.publishDate = publishDate
        self.score = score
        self.commentCount = commentCount
        self.topics = topics
        self.cachedAt = Date()
        self.isRead = isRead
    }

    var articleSource: ArticleSource {
        ArticleSource(rawValue: source) ?? .wikipedia
    }
}
