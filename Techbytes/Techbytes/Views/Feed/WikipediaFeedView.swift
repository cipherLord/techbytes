import SwiftUI
import SwiftData

struct WikipediaFeedView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = WikipediaFeedViewModel()
    @State private var selectedArticle: Article?
    @State private var isReady = false
    @State private var cardsAppeared = false
    @State private var interactionCache: [String: InteractionType] = [:]
    @State private var searchText = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @Namespace private var pillNamespace

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                if let error = viewModel.errorMessage,
                          !isReady {
                    ErrorView(message: error) {
                        await viewModel.refresh()
                        isReady = true
                    }
                } else if !isReady {
                    LoadingView(message: "Discovering articles...")
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
            guard !isReady else { return }
            await viewModel.loadContent()
            refreshInteractionCache()
            isReady = true
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
            visibleArticles = [viewModel.featuredArticle].compactMap { $0 } + viewModel.newsArticles
        case .search:
            visibleArticles = viewModel.searchResults
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
                        case .search:
                            searchSection
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

    // MARK: - Section Picker

    private var sectionPicker: some View {
        HStack(spacing: 8) {
            ForEach(WikipediaSection.allCases, id: \.rawValue) { section in
                Button {
                    if viewModel.activeSection != section {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            viewModel.activeSection = section
                        }
                    }
                } label: {
                    Text(section.rawValue)
                        .font(.label)
                        .foregroundStyle(viewModel.activeSection == section ? .snow : .dustyGrey)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
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
                .accessibilityLabel("\(section.rawValue) section")
                .accessibilityAddTraits(viewModel.activeSection == section ? .isSelected : [])
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Featured Section (Wikipedia Main Page style)

    @ViewBuilder
    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Today's Featured Article
            if let featured = viewModel.featuredArticle {
                todaysFeaturedArticleCard(featured)
                    .fadeSlideIn(index: 0, appeared: cardsAppeared)
            }

            // Picture of the Day
            if let potd = viewModel.pictureOfTheDay {
                pictureOfTheDayCard(potd)
                    .fadeSlideIn(index: 1, appeared: cardsAppeared)
            }

            // In the News
            if !viewModel.newsArticles.isEmpty {
                inTheNewsCard
                    .fadeSlideIn(index: 2, appeared: cardsAppeared)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func todaysFeaturedArticleCard(_ article: Article) -> some View {
        Button {
            selectedArticle = article
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                    CachedAsyncImage(url: url, height: 200, maxPixelSize: 600)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.liquidLava)
                        Text("TODAY'S FEATURED ARTICLE")
                            .font(.caption)
                            .foregroundStyle(.liquidLava)
                            .tracking(1.2)
                    }

                    Text(article.title)
                        .font(.headline2)
                        .foregroundStyle(.primaryText)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if !article.summary.isEmpty {
                        Text(article.summary)
                            .font(.bodyMedium)
                            .foregroundStyle(.secondaryText)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(spacing: 6) {
                        Text("Read full article")
                            .font(.label)
                            .foregroundStyle(.liquidLava)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 11))
                            .foregroundStyle(.liquidLava)
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            .background(Color.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.1), Color.white.opacity(0.03), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(PressableCardStyle())
    }

    private func pictureOfTheDayCard(_ potd: WikipediaFeedViewModel.PictureOfTheDay) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let url = URL(string: potd.imageURL) {
                CachedAsyncImage(url: url, height: 240, maxPixelSize: 800)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.artframe")
                        .font(.system(size: 11))
                        .foregroundStyle(.liquidLava)
                    Text("PICTURE OF THE DAY")
                        .font(.caption)
                        .foregroundStyle(.liquidLava)
                        .tracking(1.2)
                }

                if !potd.caption.isEmpty {
                    Text(potd.caption)
                        .font(.bodyMedium)
                        .foregroundStyle(.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        .background(Color.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.1), Color.white.opacity(0.03), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
    }

    @ViewBuilder
    private var inTheNewsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "newspaper.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.liquidLava)
                Text("In the News")
                    .font(.headline2)
                    .foregroundStyle(.primaryText)
            }
            .padding(.top, 4)

            ForEach(Array(viewModel.newsArticles.prefix(6).enumerated()), id: \.element.id) { index, article in
                articleCard(article)
                    .fadeSlideIn(index: index + 3, appeared: cardsAppeared)
            }
        }
    }

    // MARK: - Search Section

    @ViewBuilder
    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            searchBar

            if viewModel.isSearching {
                LoadingView(message: "Searching Wikipedia...")
                    .frame(height: 200)
            } else if let error = viewModel.searchError {
                emptyStateView(icon: "exclamationmark.triangle", message: error)
            } else if viewModel.searchResults.isEmpty {
                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    searchPromptView
                } else {
                    emptyStateView(icon: "magnifyingglass", message: "No results found for \"\(searchText)\"")
                }
            } else {
                ForEach(Array(viewModel.searchResults.enumerated()), id: \.element.id) { index, article in
                    articleCard(article)
                        .fadeSlideIn(index: index, appeared: cardsAppeared)
                        .onAppear {
                            if index == viewModel.searchResults.count - 3 {
                                Task { await loadMoreAndCacheInteractions() }
                            }
                        }
                }

                if viewModel.isLoadingMore {
                    loadingMoreIndicator
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(.dustyGrey)

            TextField("Search Wikipedia...", text: $searchText)
                .font(.bodyLarge)
                .foregroundStyle(.primaryText)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: searchText) { _, newValue in
                    viewModel.searchQuery = newValue
                    searchDebounceTask?.cancel()
                    searchDebounceTask = Task {
                        try? await Task.sleep(for: .milliseconds(300))
                        guard !Task.isCancelled else { return }
                        await viewModel.performSearch(query: newValue)
                        refreshInteractionCache()
                        withAnimation(.easeOut(duration: 0.4)) {
                            cardsAppeared = true
                        }
                    }
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    viewModel.searchQuery = ""
                    viewModel.searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.dustyGrey)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.slateGrey)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var searchPromptView: some View {
        VStack(spacing: 16) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(.dustyGrey)
            Text("Search Wikipedia")
                .font(.headline3)
                .foregroundStyle(.primaryText)
            Text("Find articles on any topic")
                .font(.bodyMedium)
                .foregroundStyle(.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Random Section

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

    // MARK: - Shared Components

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
