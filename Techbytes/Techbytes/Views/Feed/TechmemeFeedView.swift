import SwiftUI

struct TechmemeFeedView: View {
    @State private var viewModel = TechmemeFeedViewModel()
    @State private var safariURL: IdentifiableURL?
    @State private var cardsAppeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if viewModel.isLoading && viewModel.stories.isEmpty {
                    LoadingView(message: "Fetching stories...")
                } else if let error = viewModel.errorMessage,
                          viewModel.stories.isEmpty {
                    ErrorView(message: error) {
                        await viewModel.refresh()
                    }
                } else {
                    storyList
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $safariURL) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
        .task {
            guard viewModel.stories.isEmpty else { return }
            await viewModel.loadStories()
            withAnimation(.easeOut(duration: 0.4)) {
                cardsAppeared = true
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    @ViewBuilder
    private var storyList: some View {
        if viewModel.stories.isEmpty && !viewModel.isLoading {
            VStack(spacing: 12) {
                Image(systemName: "memorychip")
                    .font(.system(size: 36))
                    .foregroundStyle(.dustyGrey)
                Text("No stories available")
                    .font(.bodyMedium)
                    .foregroundStyle(.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 20) {
                    feedTitle("Techmeme")

                    ForEach(Array(viewModel.stories.enumerated()), id: \.element.id) { index, story in
                        Button {
                            if let url = URL(string: story.articleURL),
                               let scheme = url.scheme?.lowercased(),
                               scheme == "https" || scheme == "http" {
                                safariURL = IdentifiableURL(url: url)
                            }
                        } label: {
                            StoryCardView(article: story, rank: index + 1)
                        }
                        .buttonStyle(PressableCardStyle())
                        .fadeSlideIn(index: index, appeared: cardsAppeared)
                        .accessibilityLabel("\(story.title).")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
    }

    private func feedTitle(_ title: String) -> some View {
        Text(title)
            .font(AppFont.bold(34, relativeTo: .largeTitle))
            .foregroundStyle(.primaryText)
            .padding(.top, 8)
    }
}
