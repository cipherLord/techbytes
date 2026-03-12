import Foundation
import SwiftData

@MainActor
final class RecommendationEngine {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func scoreArticles(_ articles: [Article]) -> [Article] {
        let topics = fetchSelectedTopics()
        if topics.isEmpty { return articles }

        let scored = articles.map { article -> (Article, Double) in
            let score = calculateScore(for: article, topics: topics)
            return (article, score)
        }
        return scored
            .sorted { $0.1 > $1.1 }
            .map(\.0)
    }

    func recordInteraction(articleID: String, articleTitle: String, type: InteractionType, articleTopics: [String]) {
        let interaction = ArticleInteraction(
            articleID: articleID,
            articleTitle: articleTitle,
            interaction: type,
            matchedTopics: articleTopics
        )
        modelContext.insert(interaction)
        adjustTopicWeights(topics: articleTopics, liked: type == .like)
        try? modelContext.save()
    }

    func existingInteraction(for articleID: String) -> InteractionType? {
        let descriptor = FetchDescriptor<ArticleInteraction>(
            predicate: #Predicate { $0.articleID == articleID }
        )
        guard let interaction = try? modelContext.fetch(descriptor).first else { return nil }
        return interaction.interactionType
    }

    func batchFetchInteractions(for articleIDs: [String]) -> [String: InteractionType] {
        guard !articleIDs.isEmpty else { return [:] }
        let descriptor = FetchDescriptor<ArticleInteraction>()
        guard let allInteractions = try? modelContext.fetch(descriptor) else { return [:] }
        let idSet = Set(articleIDs)
        var result: [String: InteractionType] = [:]
        for interaction in allInteractions where idSet.contains(interaction.articleID) {
            result[interaction.articleID] = interaction.interactionType
        }
        return result
    }

    private func calculateScore(for article: Article, topics: [UserTopic]) -> Double {
        var score = 0.0
        let articleText = (article.title + " " + article.summary).lowercased()
        let articleTopicNames = Set(article.topics)

        for topic in topics where topic.isSelected {
            if articleTopicNames.contains(topic.name) {
                score += topic.weight * 2.0
            }
            let keywordHits = topic.keywords.filter { articleText.contains($0.lowercased()) }.count
            if keywordHits > 0 {
                score += Double(keywordHits) * topic.weight * 0.5
            }
        }
        return score
    }

    private func adjustTopicWeights(topics: [String], liked: Bool) {
        let descriptor = FetchDescriptor<UserTopic>(
            predicate: #Predicate { $0.isSelected == true }
        )
        guard let userTopics = try? modelContext.fetch(descriptor) else { return }
        for userTopic in userTopics {
            if topics.contains(userTopic.name) {
                let delta = liked ? 0.15 : -0.1
                userTopic.weight = max(0.1, min(3.0, userTopic.weight + delta))
            }
        }
    }

    private func fetchSelectedTopics() -> [UserTopic] {
        let descriptor = FetchDescriptor<UserTopic>(
            predicate: #Predicate { $0.isSelected == true }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
