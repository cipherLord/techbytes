import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class TagManagerViewModel {
    var topics: [UserTopic] = []
    var newTagName = ""
    var hasCompletedOnboarding = false

    private var modelContext: ModelContext?

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadTopics()
        checkOnboardingStatus()
    }

    func loadTopics() {
        guard let modelContext else { return }
        let descriptor = FetchDescriptor<UserTopic>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        topics = (try? modelContext.fetch(descriptor)) ?? []
    }

    func seedPredefinedTopics() {
        guard let modelContext else { return }
        for (index, predefined) in UserTopic.predefined.enumerated() {
            let topic = UserTopic(
                name: predefined.name,
                keywords: predefined.keywords,
                sortOrder: index
            )
            modelContext.insert(topic)
        }
        try? modelContext.save()
        loadTopics()
    }

    func toggleTopic(_ topic: UserTopic) {
        topic.isSelected.toggle()
        try? modelContext?.save()
    }

    static let maxTagLength = 40

    func addCustomTag() {
        guard let modelContext else { return }
        let trimmed = String(newTagName.trimmingCharacters(in: .whitespaces).prefix(Self.maxTagLength))
        guard !trimmed.isEmpty else { return }

        let duplicate = topics.contains { $0.name.lowercased() == trimmed.lowercased() }
        guard !duplicate else {
            newTagName = ""
            return
        }

        let tag = UserTopic(
            name: trimmed,
            keywords: trimmed.lowercased().components(separatedBy: " "),
            isSelected: true,
            isCustom: true,
            sortOrder: topics.count
        )
        modelContext.insert(tag)
        try? modelContext.save()
        newTagName = ""
        loadTopics()
    }

    func deleteTopic(_ topic: UserTopic) {
        modelContext?.delete(topic)
        try? modelContext?.save()
        loadTopics()
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    private func checkOnboardingStatus() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        if topics.isEmpty && !hasCompletedOnboarding {
            seedPredefinedTopics()
        }
    }

    var selectedTopics: [UserTopic] {
        topics.filter(\.isSelected)
    }

    var customTopics: [UserTopic] {
        topics.filter(\.isCustom)
    }
}
