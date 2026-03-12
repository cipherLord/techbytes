import Foundation
import SwiftData

enum InteractionType: String, Codable {
    case like
    case dislike
}

@Model
final class ArticleInteraction {
    @Attribute(.unique) var id: String
    var articleID: String
    var articleTitle: String
    var interaction: String
    var matchedTopics: [String]
    var timestamp: Date

    init(
        articleID: String,
        articleTitle: String,
        interaction: InteractionType,
        matchedTopics: [String] = []
    ) {
        self.id = UUID().uuidString
        self.articleID = articleID
        self.articleTitle = articleTitle
        self.interaction = interaction.rawValue
        self.matchedTopics = matchedTopics
        self.timestamp = Date()
    }

    var interactionType: InteractionType {
        InteractionType(rawValue: interaction) ?? .like
    }
}
