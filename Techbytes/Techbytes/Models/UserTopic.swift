import Foundation
import SwiftData

@Model
final class UserTopic {
    @Attribute(.unique) var id: String
    var name: String
    var keywords: [String]
    var isSelected: Bool
    var weight: Double
    var createdAt: Date
    var isCustom: Bool
    var sortOrder: Int

    init(
        name: String,
        keywords: [String],
        isSelected: Bool = false,
        weight: Double = 1.0,
        isCustom: Bool = false,
        sortOrder: Int = 0
    ) {
        self.id = UUID().uuidString
        self.name = name
        self.keywords = keywords
        self.isSelected = isSelected
        self.weight = weight
        self.createdAt = Date()
        self.isCustom = isCustom
        self.sortOrder = sortOrder
    }

    static let predefined: [(name: String, keywords: [String])] = [
        ("Science", ["science", "physics", "chemistry", "biology", "research", "experiment", "scientific", "laboratory", "quantum"]),
        ("Technology", ["technology", "computer", "software", "hardware", "digital", "internet", "programming", "AI", "artificial intelligence", "machine learning"]),
        ("History", ["history", "war", "empire", "dynasty", "ancient", "century", "historical", "civilization", "medieval", "revolution"]),
        ("Art & Culture", ["art", "music", "painting", "sculpture", "museum", "film", "literature", "theater", "opera", "gallery"]),
        ("Sports", ["sport", "football", "basketball", "olympics", "championship", "athlete", "soccer", "tennis", "cricket", "baseball"]),
        ("Geography", ["geography", "country", "continent", "island", "mountain", "ocean", "river", "desert", "climate", "population"]),
        ("Medicine", ["medicine", "health", "disease", "treatment", "hospital", "surgery", "vaccine", "diagnosis", "pharmaceutical", "anatomy"]),
        ("Space", ["space", "planet", "star", "galaxy", "NASA", "astronaut", "telescope", "orbit", "nebula", "cosmos"]),
        ("Philosophy", ["philosophy", "ethics", "logic", "metaphysics", "existentialism", "philosopher", "epistemology", "moral", "consciousness"]),
        ("Politics", ["politics", "government", "election", "democracy", "law", "policy", "president", "parliament", "legislation", "constitution"]),
        ("Nature", ["nature", "environment", "climate", "ecosystem", "wildlife", "conservation", "endangered", "rainforest", "biodiversity"]),
        ("Mathematics", ["mathematics", "theorem", "equation", "algebra", "geometry", "calculus", "probability", "statistics", "mathematical"])
    ]
}
