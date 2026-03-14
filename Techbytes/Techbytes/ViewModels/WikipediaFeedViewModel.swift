import Foundation
import SwiftData
import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.techbytes", category: "WikipediaFeed")
private let maxArticlesPerSection = 30

@MainActor
@Observable
final class WikipediaFeedViewModel {
    // MARK: - Featured state
    var featuredArticle: Article?
    var newsArticles: [Article] = []
    var pictureOfTheDay: PictureOfTheDay?
    var randomArticles: [Article] = []

    // MARK: - Search state
    var searchResults: [Article] = []
    var searchQuery = ""
    var isSearching = false
    var searchError: String?
    private var searchOffset = 0
    private var hasMoreSearchResults = true

    // MARK: - General state
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?
    var randomError: String?
    var activeSection: WikipediaSection = .featured

    private let service = WikipediaService.shared
    var recommendationEngine: RecommendationEngine?

    private var seenArticleIDs: Set<String> = []
    private var featuredDayOffset = 0

    struct PictureOfTheDay {
        let imageURL: String
        let caption: String
        let title: String
    }

    func configure(modelContext: ModelContext) {
        if recommendationEngine == nil {
            recommendationEngine = RecommendationEngine(modelContext: modelContext)
        }
    }

    func loadContent() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        resetPagination()

        async let featured: Void = loadFeatured(ignoreCache: false)
        async let random: Void = loadRandom(ignoreCache: false)

        _ = await (featured, random)
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        resetPagination()

        async let featured: Void = loadFeatured(ignoreCache: true)
        async let random: Void = loadRandom(ignoreCache: true)

        _ = await (featured, random)
    }

    func loadMore() async {
        guard !isLoadingMore, !isLoading else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        switch activeSection {
        case .featured:
            break
        case .search:
            await loadMoreSearchResults()
        case .random:
            await loadMoreRandom()
        }
    }

    // MARK: - Search

    func performSearch(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            searchError = nil
            searchOffset = 0
            hasMoreSearchResults = true
            return
        }

        isSearching = true
        searchError = nil
        searchOffset = 0
        hasMoreSearchResults = true
        searchResults = []
        defer { isSearching = false }

        do {
            let (summaries, nextOffset) = try await service.searchArticles(query: trimmed, limit: 10, offset: 0)
            guard !Task.isCancelled else { return }
            let articles = service.toArticles(from: summaries, section: .search)
            searchResults = articles
            searchOffset = nextOffset ?? 0
            hasMoreSearchResults = nextOffset != nil
        } catch {
            guard !Task.isCancelled else { return }
            let message = (error as? NetworkError)?.userMessage ?? error.localizedDescription
            logger.error("Search failed: \(message)")
            searchError = "Search failed. Please try again."
        }
    }

    private func loadMoreSearchResults() async {
        guard hasMoreSearchResults, !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            let (summaries, nextOffset) = try await service.searchArticles(
                query: searchQuery.trimmingCharacters(in: .whitespacesAndNewlines),
                limit: 10,
                offset: searchOffset
            )
            guard !Task.isCancelled else { return }
            let articles = service.toArticles(from: summaries, section: .search)
            let newArticles = articles.filter { article in !searchResults.contains(where: { $0.id == article.id }) }
            searchResults.append(contentsOf: newArticles)
            searchOffset = nextOffset ?? searchOffset
            hasMoreSearchResults = nextOffset != nil
        } catch {
            logger.error("Failed to load more search results: \(error.localizedDescription)")
        }
    }

    // MARK: - Pagination helpers

    private func resetPagination() {
        seenArticleIDs.removeAll()
        featuredDayOffset = 0
    }

    private func markSeen(_ articles: [Article]) {
        for article in articles {
            seenArticleIDs.insert(article.id)
        }
    }

    private func dedup(_ articles: [Article]) -> [Article] {
        var result: [Article] = []
        for article in articles {
            if !seenArticleIDs.contains(article.id) {
                seenArticleIDs.insert(article.id)
                result.append(article)
            }
        }
        return result
    }

    // MARK: - Load More Random

    private func loadMoreRandom() async {
        guard randomArticles.count < maxArticlesPerSection else { return }
        do {
            let summaries = try await service.fetchRandomArticles(count: 8, ignoreCache: true)
            guard !Task.isCancelled else { return }
            let newArticles = service.toArticles(from: summaries, section: .random)
            let unique = dedup(newArticles)
            let ranked = recommendationEngine?.scoreArticles(unique) ?? unique
            let remaining = maxArticlesPerSection - randomArticles.count
            randomArticles.append(contentsOf: ranked.prefix(remaining))
        } catch {
            logger.error("Failed to load more random articles: \(error.localizedDescription)")
        }
    }

    // MARK: - Initial Loaders

    private func loadFeatured(ignoreCache: Bool) async {
        do {
            let response = try await service.fetchFeaturedContent(ignoreCache: ignoreCache)
            guard !Task.isCancelled else { return }

            if let tfa = response.tfa {
                let articles = service.toArticles(from: [tfa], section: .featured)
                featuredArticle = articles.first
                if let featured = featuredArticle {
                    seenArticleIDs.insert(featured.id)
                }
            }

            if let news = response.news, !news.isEmpty {
                newsArticles = service.toArticles(from: news)
                markSeen(newsArticles)
            }

            if let image = response.image {
                let imageURL = image.image?.source ?? image.thumbnail?.source
                let caption = image.description?.text ?? ""
                let title = image.title ?? ""
                if let url = imageURL {
                    pictureOfTheDay = PictureOfTheDay(imageURL: url, caption: caption, title: title)
                }
            }
        } catch {
            errorMessage = (error as? NetworkError)?.userMessage ?? "Failed to load content. Please try again."
        }
    }

    private func loadRandom(ignoreCache: Bool) async {
        do {
            let summaries = try await service.fetchRandomArticles(ignoreCache: ignoreCache)
            guard !Task.isCancelled else { return }
            let articles = service.toArticles(from: summaries, section: .random)
            randomArticles = recommendationEngine?.scoreArticles(articles) ?? articles
            markSeen(randomArticles)
            randomError = nil
        } catch {
            guard !Task.isCancelled else { return }
            let message = (error as? NetworkError)?.userMessage ?? error.localizedDescription
            logger.error("Failed to load Random articles: \(message)")
            randomError = "Failed to load random articles."
        }
    }
}
