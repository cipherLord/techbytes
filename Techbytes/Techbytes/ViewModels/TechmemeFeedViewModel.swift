import Foundation
import SwiftUI

@MainActor
@Observable
final class TechmemeFeedViewModel {
    var stories: [Article] = []
    var isLoading = false
    var errorMessage: String?

    private let service = TechmemeService.shared

    func loadStories(ignoreCache: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            stories = try await service.fetchStories(ignoreCache: ignoreCache)
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
}
