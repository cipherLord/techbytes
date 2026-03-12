import Foundation
import SwiftData

enum ArticleSource: String, Codable {
    case wikipedia
    case hackerNews
}

enum WikipediaSection: String, Codable, CaseIterable {
    case featured = "Featured"
    case mostRead = "Most Read"
    case onThisDay = "On This Day"
    case random = "Random"
}

enum HackerNewsSection: String, Codable, CaseIterable {
    case top = "Top"
    case new = "New"
    case best = "Best"
    case ask = "Ask"
    case show = "Show"
    case jobs = "Jobs"
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
