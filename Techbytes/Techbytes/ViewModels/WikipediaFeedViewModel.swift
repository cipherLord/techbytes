import Foundation
import SwiftData
import SwiftUI
import OSLog

private let logger = Logger(subsystem: "com.techbytes", category: "WikipediaFeed")
private let maxArticlesPerSection = 30

@MainActor
@Observable
final class WikipediaFeedViewModel {
    var featuredArticle: Article?
    var mostReadArticles: [Article] = []
    var onThisDayArticles: [Article] = []
    var randomArticles: [Article] = []
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?
    var onThisDayError: String?
    var randomError: String?
    var activeSection: WikipediaSection = .featured

    private let service = WikipediaService.shared
    var recommendationEngine: RecommendationEngine?

    private var seenArticleIDs: Set<String> = []
    private var featuredDayOffset = 0
    private var mostReadDayOffset = 0
    private var onThisDayDayOffset = 0

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

        async let featured: Void = loadFeaturedAndMostRead(ignoreCache: false)
        async let onThisDay: Void = loadOnThisDay(ignoreCache: false)
        async let random: Void = loadRandom(ignoreCache: false)

        _ = await (featured, onThisDay, random)
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        resetPagination()

        async let featured: Void = loadFeaturedAndMostRead(ignoreCache: true)
        async let onThisDay: Void = loadOnThisDay(ignoreCache: true)
        async let random: Void = loadRandom(ignoreCache: true)

        _ = await (featured, onThisDay, random)
    }

    func loadMore() async {
        guard !isLoadingMore, !isLoading else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        switch activeSection {
        case .featured:
            await loadMoreFeatured()
        case .mostRead:
            await loadMoreMostRead()
        case .onThisDay:
            await loadMoreOnThisDay()
        case .random:
            await loadMoreRandom()
        }
    }

    private func resetPagination() {
        seenArticleIDs.removeAll()
        featuredDayOffset = 0
        mostReadDayOffset = 0
        onThisDayDayOffset = 0
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

    // MARK: - Load More (per section)

    private func loadMoreFeatured() async {
        guard mostReadArticles.count < maxArticlesPerSection else { return }
        featuredDayOffset += 1
        guard let targetDate = Calendar.current.date(byAdding: .day, value: -featuredDayOffset, to: Date()) else { return }
        do {
            let response = try await service.fetchFeaturedContent(date: targetDate, ignoreCache: false)
            guard !Task.isCancelled else { return }

            var newArticles: [Article] = []
            if let tfa = response.tfa {
                newArticles.append(contentsOf: service.toArticles(from: [tfa], section: .featured))
            }
            if let readArticles = response.mostread?.articles, !readArticles.isEmpty {
                newArticles.append(contentsOf: service.toArticles(from: readArticles, section: .mostRead))
            }

            let unique = dedup(newArticles)
            let ranked = recommendationEngine?.scoreArticles(unique) ?? unique
            let remaining = maxArticlesPerSection - mostReadArticles.count
            mostReadArticles.append(contentsOf: ranked.prefix(remaining))
        } catch {
            logger.error("Failed to load more featured content: \(error.localizedDescription)")
        }
    }

    private func loadMoreMostRead() async {
        guard mostReadArticles.count < maxArticlesPerSection else { return }
        mostReadDayOffset += 1
        guard let targetDate = Calendar.current.date(byAdding: .day, value: -mostReadDayOffset, to: Date()) else { return }
        do {
            let response = try await service.fetchFeaturedContent(date: targetDate, ignoreCache: false)
            guard !Task.isCancelled else { return }

            if let readArticles = response.mostread?.articles, !readArticles.isEmpty {
                let converted = service.toArticles(from: readArticles, section: .mostRead)
                let unique = dedup(converted)
                let ranked = recommendationEngine?.scoreArticles(unique) ?? unique
                let remaining = maxArticlesPerSection - mostReadArticles.count
                mostReadArticles.append(contentsOf: ranked.prefix(remaining))
            }
        } catch {
            logger.error("Failed to load more most read: \(error.localizedDescription)")
        }
    }

    private func loadMoreOnThisDay() async {
        guard onThisDayArticles.count < maxArticlesPerSection else { return }
        onThisDayDayOffset += 1
        guard let targetDate = Calendar.current.date(byAdding: .day, value: -onThisDayDayOffset, to: Date()) else { return }
        do {
            let events = try await service.fetchOnThisDay(date: targetDate, ignoreCache: false)
            guard !Task.isCancelled else { return }
            let converted = service.toArticles(from: events)
            let unique = dedup(converted)
            let remaining = maxArticlesPerSection - onThisDayArticles.count
            onThisDayArticles.append(contentsOf: unique.prefix(remaining))
        } catch {
            logger.error("Failed to load more On This Day: \(error.localizedDescription)")
        }
    }

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

    private func loadFeaturedAndMostRead(ignoreCache: Bool) async {
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

            if let readArticles = response.mostread?.articles, !readArticles.isEmpty {
                let converted = service.toArticles(from: Array(readArticles.prefix(20)), section: .mostRead)
                mostReadArticles = recommendationEngine?.scoreArticles(converted) ?? converted
                markSeen(mostReadArticles)
            } else {
                let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
                let fallback = try await service.fetchFeaturedContent(date: yesterday, ignoreCache: ignoreCache)
                guard !Task.isCancelled else { return }
                if let readArticles = fallback.mostread?.articles, !readArticles.isEmpty {
                    let converted = service.toArticles(from: Array(readArticles.prefix(20)), section: .mostRead)
                    mostReadArticles = recommendationEngine?.scoreArticles(converted) ?? converted
                    markSeen(mostReadArticles)
                }
            }
        } catch {
            errorMessage = (error as? NetworkError)?.userMessage ?? "Failed to load content. Please try again."
        }
    }

    private func loadOnThisDay(ignoreCache: Bool) async {
        do {
            let events = try await service.fetchOnThisDay(ignoreCache: ignoreCache)
            guard !Task.isCancelled else { return }
            onThisDayArticles = service.toArticles(from: events)
            markSeen(onThisDayArticles)
            onThisDayError = nil
        } catch {
            guard !Task.isCancelled else { return }
            let message = (error as? NetworkError)?.userMessage ?? error.localizedDescription
            logger.error("Failed to load On This Day: \(message)")
            onThisDayError = "Failed to load historical events."
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
