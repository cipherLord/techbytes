import Foundation
import SwiftUI

@MainActor
@Observable
final class LobstersFeedViewModel {
    var stories: [Article] = []
    var isLoading = false
    var errorMessage: String?
    var activeSection: LobstersSection = .hottest

    private let service = LobstersService.shared

    func loadStories(ignoreCache: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            stories = try await service.fetchStories(section: activeSection, ignoreCache: ignoreCache)
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

    func switchSection(_ section: LobstersSection) async {
        activeSection = section
        isLoading = false
        await loadStories()
    }
}
