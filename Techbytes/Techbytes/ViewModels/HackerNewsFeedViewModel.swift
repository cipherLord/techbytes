import Foundation
import SwiftUI

@MainActor
@Observable
final class HackerNewsFeedViewModel {
    var stories: [Article] = []
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?
    var activeSection: HackerNewsSection = .top
    private var currentOffset = 0
    private var cachedStoryIDs: [Int] = []

    private let service = HackerNewsService.shared

    func loadStories(ignoreCache: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        currentOffset = 0
        cachedStoryIDs = []

        do {
            cachedStoryIDs = try await service.fetchStoryIDs(section: activeSection, ignoreCache: ignoreCache)
            guard !Task.isCancelled else { return }
            let batchIDs = Array(cachedStoryIDs.prefix(25))
            stories = try await service.fetchStoriesFromIDs(batchIDs, section: activeSection)
            currentOffset = stories.count
        } catch {
            if !Task.isCancelled {
                errorMessage = (error as? NetworkError)?.userMessage ?? "Failed to load stories. Please try again."
            }
        }
    }

    func refresh() async {
        isLoading = false
        await loadStories(ignoreCache: true)
    }

    func switchSection(_ section: HackerNewsSection) async {
        activeSection = section
        isLoading = false
        await loadStories()
    }

    func loadMore() async {
        guard !isLoadingMore, currentOffset < cachedStoryIDs.count else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let batchIDs = Array(cachedStoryIDs.dropFirst(currentOffset).prefix(15))
            guard !batchIDs.isEmpty else { return }
            let moreStories = try await service.fetchStoriesFromIDs(batchIDs, section: activeSection)
            guard !Task.isCancelled else { return }
            stories.append(contentsOf: moreStories)
            currentOffset += moreStories.count
        } catch {
            // Pagination: non-critical
        }
    }
}
