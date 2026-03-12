import Foundation
import SwiftUI

@MainActor
@Observable
final class ArticleReaderViewModel {
    var fullContent: String?
    var isLoading = false
    var errorMessage: String?

    private let wikiService = WikipediaService.shared

    func loadFullArticle(for article: Article) async {
        guard article.articleSource == .wikipedia else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        let title = article.title

        do {
            let html = try await wikiService.fetchFullArticleHTML(title: title)
            guard !Task.isCancelled else { return }
            fullContent = html
        } catch {
            guard !Task.isCancelled else { return }
            do {
                let summary = try await wikiService.fetchArticleSummary(title: title)
                guard !Task.isCancelled else { return }
                fullContent = summary.extractHtml ?? summary.extract
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = "Unable to load article content."
                fullContent = nil
            }
        }
    }
}
