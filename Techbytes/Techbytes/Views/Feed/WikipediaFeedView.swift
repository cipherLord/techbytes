import SwiftUI
import SwiftData

struct WikipediaFeedView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = WikipediaFeedViewModel()
    @State private var selectedArticle: Article?
    @State private var cardsAppeared = false
    @State private var interactionCache: [String: InteractionType] = [:]
    @Namespace private var pillNamespace

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if viewModel.isLoading && viewModel.featuredArticle == nil {
                    LoadingView(message: "Discovering articles...")
                } else if let error = viewModel.errorMessage,
                          viewModel.featuredArticle == nil {
                    ErrorView(message: error) {
                        await viewModel.refresh()
                    }
                } else {
                    feedContent
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(item: $selectedArticle) { article in
                ArticleReaderView(article: article)
            }
        }
        .task {
            viewModel.configure(modelContext: modelContext)
            guard viewModel.featuredArticle == nil else { return }
            await viewModel.loadContent()
            refreshInteractionCache()
            withAnimation(.easeOut(duration: 0.4)) {
                cardsAppeared = true
            }
        }
        .refreshable {
            await viewModel.refresh()
            refreshInteractionCache()
        }
    }

    private func refreshInteractionCache() {
        let visibleArticles: [Article]
        switch viewModel.activeSection {
        case .featured:
            visibleArticles = [viewModel.featuredArticle].compactMap { $0 } + viewModel.mostReadArticles
        case .mostRead:
            visibleArticles = viewModel.mostReadArticles
        case .onThisDay:
            visibleArticles = viewModel.onThisDayArticles
        case .random:
            visibleArticles = viewModel.randomArticles
        }
        guard !visibleArticles.isEmpty else { return }
        let ids = visibleArticles.map(\.id)
        let fetched = viewModel.recommendationEngine?.batchFetchInteractions(for: ids) ?? [:]
        interactionCache.merge(fetched) { _, new in new }
    }

    @ViewBuilder
    private var feedContent: some View {
        VStack(spacing: 0) {
            sectionPicker

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 32) {
                        feedTitle("Wikipedia")

                        switch viewModel.activeSection {
                        case .featured:
                            featuredSection
                                .transition(.opacity)
                        case .mostRead:
                            mostReadSection
                                .transition(.opacity)
                        case .onThisDay:
                            onThisDaySection
                                .transition(.opacity)
                        case .random:
                            randomSection
                                .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                    .id("scrollTop")
                }
                .onChange(of: viewModel.activeSection) { _, _ in
                    cardsAppeared = false
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("scrollTop", anchor: .top)
                    }
                    Task {
                        try? await Task.sleep(for: .milliseconds(150))
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeOut(duration: 0.4)) {
                            cardsAppeared = true
                        }
                    }
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
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(WikipediaSection.allCases, id: \.rawValue) { section in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                viewModel.activeSection = section
                            }
                        } label: {
                            Text(section.rawValue)
                                .font(.label)
                                .foregroundStyle(viewModel.activeSection == section ? .snow : .dustyGrey)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background {
                                    if viewModel.activeSection == section {
                                        Capsule()
                                            .fill(Color.liquidLava)
                                            .matchedGeometryEffect(id: "activePill", in: pillNamespace)
                                    } else {
                                        Capsule()
                                            .fill(Color.slateGrey)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .id(section)
                        .accessibilityLabel("\(section.rawValue) section")
                        .accessibilityAddTraits(viewModel.activeSection == section ? .isSelected : [])
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.activeSection) { _, newSection in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    proxy.scrollTo(newSection, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 32) {
            if let featured = viewModel.featuredArticle {
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeader("Today's Featured Article")
                        .fadeSlideIn(index: 0, appeared: cardsAppeared)
                    articleCard(featured)
                        .fadeSlideIn(index: 1, appeared: cardsAppeared)
                }
            }

            if !viewModel.mostReadArticles.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    sectionHeader("Trending Now")
                        .fadeSlideIn(index: 2, appeared: cardsAppeared)
                    ForEach(Array(viewModel.mostReadArticles.enumerated()), id: \.element.id) { index, article in
                        articleCard(article)
                            .fadeSlideIn(index: index + 3, appeared: cardsAppeared)
                            .onAppear {
                                if index == viewModel.mostReadArticles.count - 3 {
                                    Task { await loadMoreAndCacheInteractions() }
                                }
                            }
                    }
                }
            }

            if viewModel.isLoadingMore {
                loadingMoreIndicator
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var mostReadSection: some View {
        VStack(alignment: .leading, spacing: 32) {
            if viewModel.mostReadArticles.isEmpty {
                emptyStateView(icon: "chart.bar", message: "No trending articles available")
            } else {
                ForEach(Array(viewModel.mostReadArticles.enumerated()), id: \.element.id) { index, article in
                    articleCard(article)
                        .fadeSlideIn(index: index, appeared: cardsAppeared)
                        .onAppear {
                            if index == viewModel.mostReadArticles.count - 3 {
                                Task { await loadMoreAndCacheInteractions() }
                            }
                        }
                }
            }

            if viewModel.isLoadingMore {
                loadingMoreIndicator
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var onThisDaySection: some View {
        VStack(alignment: .leading, spacing: 32) {
            if viewModel.onThisDayArticles.isEmpty {
                emptyStateView(
                    icon: "calendar",
                    message: viewModel.onThisDayError ?? "No historical events found for today"
                )
            } else {
                sectionHeader("On This Day")
                    .fadeSlideIn(index: 0, appeared: cardsAppeared)
                ForEach(Array(viewModel.onThisDayArticles.enumerated()), id: \.element.id) { index, article in
                    articleCard(article)
                        .fadeSlideIn(index: index + 1, appeared: cardsAppeared)
                        .onAppear {
                            if index == viewModel.onThisDayArticles.count - 3 {
                                Task { await loadMoreAndCacheInteractions() }
                            }
                        }
                }
            }

            if viewModel.isLoadingMore {
                loadingMoreIndicator
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var randomSection: some View {
        VStack(alignment: .leading, spacing: 32) {
            if viewModel.randomArticles.isEmpty {
                emptyStateView(
                    icon: "dice",
                    message: viewModel.randomError ?? "No random articles loaded yet"
                )
            } else {
                ForEach(Array(viewModel.randomArticles.enumerated()), id: \.element.id) { index, article in
                    articleCard(article)
                        .fadeSlideIn(index: index, appeared: cardsAppeared)
                        .onAppear {
                            if index == viewModel.randomArticles.count - 3 {
                                Task { await loadMoreAndCacheInteractions() }
                            }
                        }
                }
            }

            if viewModel.isLoadingMore {
                loadingMoreIndicator
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadingMoreIndicator: some View {
        ProgressView()
            .tint(.liquidLava)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
    }

    private func loadMoreAndCacheInteractions() async {
        await viewModel.loadMore()
        refreshInteractionCache()
    }

    private func articleCard(_ article: Article) -> some View {
        let interaction = interactionCache[article.id]
        return Button {
            selectedArticle = article
        } label: {
            ArticleCardView(
                article: article,
                onLike: {
                    viewModel.recommendationEngine?.recordInteraction(
                        articleID: article.id,
                        articleTitle: article.title,
                        type: .like,
                        articleTopics: article.topics
                    )
                    interactionCache[article.id] = .like
                },
                onDislike: {
                    viewModel.recommendationEngine?.recordInteraction(
                        articleID: article.id,
                        articleTitle: article.title,
                        type: .dislike,
                        articleTopics: article.topics
                    )
                    interactionCache[article.id] = .dislike
                },
                currentInteraction: interaction
            )
        }
        .buttonStyle(PressableCardStyle())
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline2)
            .foregroundStyle(.primaryText)
            .padding(.top, 12)
    }

    private func emptyStateView(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(.dustyGrey)
            Text(message)
                .font(.bodyMedium)
                .foregroundStyle(.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
