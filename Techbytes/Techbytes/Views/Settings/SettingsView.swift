import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var cacheCleared = false
    @State private var showClearCacheConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                List {
                    topicsSection
                    cacheSection
                    aboutSection
                }
                .scrollContentBackground(.hidden)
                .listRowBackground(Color.cardBackground)
            }
            .navigationTitle("Settings")
            .toolbarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .confirmationDialog("Clear Cache", isPresented: $showClearCacheConfirmation, titleVisibility: .visible) {
                Button("Clear Cache", role: .destructive) {
                    clearCache()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove all cached data. You may need to re-download content.")
            }
        }
    }

    private var topicsSection: some View {
        Section {
            NavigationLink {
                TagManagerView()
            } label: {
                Label {
                    Text("Manage Topics")
                        .font(.bodyLarge)
                        .foregroundStyle(.primaryText)
                } icon: {
                    Image(systemName: "tag.fill")
                        .foregroundStyle(.liquidLava)
                }
            }
            .listRowBackground(Color.cardBackground)

            NavigationLink {
                interactionHistoryView
            } label: {
                Label {
                    Text("Interaction History")
                        .font(.bodyLarge)
                        .foregroundStyle(.primaryText)
                } icon: {
                    Image(systemName: "heart.text.square.fill")
                        .foregroundStyle(.liquidLava)
                }
            }
            .listRowBackground(Color.cardBackground)
        } header: {
            Text("Personalization")
                .font(.caption)
                .foregroundStyle(.dustyGrey)
        }
    }

    private var cacheSection: some View {
        Section {
            Button {
                showClearCacheConfirmation = true
            } label: {
                Label {
                    HStack {
                        Text("Clear Cache")
                            .font(.bodyLarge)
                            .foregroundStyle(.primaryText)
                        Spacer()
                        if cacheCleared {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                } icon: {
                    Image(systemName: "trash.fill")
                        .foregroundStyle(.liquidLava)
                }
            }
            .listRowBackground(Color.cardBackground)
        } header: {
            Text("Storage")
                .font(.caption)
                .foregroundStyle(.dustyGrey)
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Label {
                    Text("Version")
                        .font(.bodyLarge)
                        .foregroundStyle(.primaryText)
                } icon: {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.liquidLava)
                }
                Spacer()
                Text("1.0.0")
                    .font(.bodyMedium)
                    .foregroundStyle(.dustyGrey)
            }
            .listRowBackground(Color.cardBackground)

            HStack {
                Label {
                    Text("Data Sources")
                        .font(.bodyLarge)
                        .foregroundStyle(.primaryText)
                } icon: {
                    Image(systemName: "globe")
                        .foregroundStyle(.liquidLava)
                }
                Spacer()
                Text("Wikipedia, Hacker News, Lobsters, Techmeme")
                    .font(.bodySmall)
                    .foregroundStyle(.dustyGrey)
            }
            .listRowBackground(Color.cardBackground)
        } header: {
            Text("About")
                .font(.caption)
                .foregroundStyle(.dustyGrey)
        }
    }

    private var interactionHistoryView: some View {
        InteractionHistoryView()
    }

    private func clearCache() {
        URLCache.shared.removeAllCachedResponses()
        Task { await ImageCache.shared.clearAll() }
        cacheCleared = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            cacheCleared = false
        }
    }
}

struct InteractionHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var interactions: [ArticleInteraction] = []

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if interactions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(.dustyGrey)
                    Text("No interactions yet")
                        .font(.headline3)
                        .foregroundStyle(.secondaryText)
                    Text("Like or dislike Wikipedia articles\nto build your profile")
                        .font(.bodyMedium)
                        .foregroundStyle(.dustyGrey)
                        .multilineTextAlignment(.center)
                }
            } else {
                List(interactions, id: \.id) { interaction in
                    HStack(spacing: 12) {
                        Image(systemName: interaction.interactionType == .like
                              ? "hand.thumbsup.fill"
                              : "hand.thumbsdown.fill")
                        .foregroundStyle(interaction.interactionType == .like
                                         ? Color.liquidLava
                                         : Color.dustyGrey)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(interaction.articleTitle)
                                .font(.label)
                                .foregroundStyle(.primaryText)
                                .lineLimit(2)
                            Text(interaction.timestamp.timeAgoDisplay)
                                .font(.caption)
                                .foregroundStyle(.dustyGrey)
                        }
                    }
                    .listRowBackground(Color.cardBackground)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("History")
        .toolbarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { loadInteractions() }
    }

    private func loadInteractions() {
        let descriptor = FetchDescriptor<ArticleInteraction>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        interactions = (try? modelContext.fetch(descriptor)) ?? []
    }
}
