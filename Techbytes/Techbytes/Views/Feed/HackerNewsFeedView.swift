import SwiftUI

struct HackerNewsFeedView: View {
    @State private var viewModel = HackerNewsFeedViewModel()
    @State private var safariURL: IdentifiableURL?
    @State private var cardsAppeared = false
    @Namespace private var pillNamespace

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
        VStack(spacing: 0) {
            sectionPicker
                .padding(.horizontal, 16)

            if viewModel.stories.isEmpty && !viewModel.isLoading {
                VStack(spacing: 12) {
                    Image(systemName: "newspaper")
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
                        feedTitle("Hacker News")

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
                            .accessibilityLabel("\(story.title). Score \(story.score ?? 0). \(story.commentCount ?? 0) comments.")
                            .onAppear {
                                if index == viewModel.stories.count - 3 {
                                    Task { await viewModel.loadMore() }
                                }
                            }
                        }

                        if viewModel.isLoadingMore {
                            ProgressView()
                                .tint(.liquidLava)
                                .padding()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    private func feedTitle(_ title: String) -> some View {
        Text(title)
            .font(AppFont.bold(34, relativeTo: .largeTitle))
            .foregroundStyle(.primaryText)
            .padding(.top, 8)
    }

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(HackerNewsSection.allCases, id: \.rawValue) { section in
                    Button {
                        cardsAppeared = false
                        Task {
                            await viewModel.switchSection(section)
                            withAnimation(.easeOut(duration: 0.4)) {
                                cardsAppeared = true
                            }
                        }
                    } label: {
                        Text(section.rawValue)
                            .font(.label)
                            .foregroundStyle(
                                viewModel.activeSection == section ? .snow : .dustyGrey
                            )
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background {
                                if viewModel.activeSection == section {
                                    Capsule()
                                        .fill(Color.liquidLava)
                                        .matchedGeometryEffect(id: "hnActivePill", in: pillNamespace)
                                } else {
                                    Capsule()
                                        .fill(Color.slateGrey)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(section.rawValue) section")
                    .accessibilityAddTraits(viewModel.activeSection == section ? .isSelected : [])
                }
            }
            .padding(.vertical, 8)
        }
    }
}
