import SwiftUI

private struct WikiLink: Hashable, Identifiable {
    let id = UUID()
    let title: String
    let pageURL: String
    let section: String?
}

struct ArticleReaderView: View {
    let article: Article
    var depth: Int = 0
    private static let maxDepth = 2

    @State private var viewModel = ArticleReaderViewModel()
    @State private var webViewHeight: CGFloat = 400
    @State private var safariURL: IdentifiableURL?
    @State private var linkedPage: WikiLink?
    @State private var appeared = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    headerSection
                    Divider()
                        .background(Color.slateGrey)
                        .cascadeIn(delay: 0.35, appeared: appeared)
                    contentSection
                        .cascadeIn(delay: 0.4, appeared: appeared)
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(item: $linkedPage) { link in
            ArticleReaderView(
                article: Article(
                    id: "wiki-link-\(link.title.hashValue)",
                    title: link.title,
                    summary: "",
                    articleURL: link.pageURL,
                    source: .wikipedia,
                    section: link.section
                ),
                depth: depth + 1
            )
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if let url = URL(string: article.articleURL),
                       let scheme = url.scheme?.lowercased(),
                       scheme == "https" || scheme == "http" {
                        openURL(url)
                    }
                } label: {
                    Image(systemName: "safari")
                        .foregroundStyle(.liquidLava)
                }
                .accessibilityLabel("Open in Safari")
            }

            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: article.articleURL) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.liquidLava)
                }
                .accessibilityLabel("Share article")
            }
        }
        .sheet(item: $safariURL) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
        .task {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
            await viewModel.loadFullArticle(for: article)
        }
        .onDisappear {
            viewModel.fullContent = nil
        }
    }

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                CachedAsyncImage(url: url, height: 240, maxPixelSize: 500)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .cascadeIn(delay: 0.0, appeared: appeared)
            }

            HStack(spacing: 8) {
                Text(article.articleSource == .wikipedia ? "WIKIPEDIA" : "HACKER NEWS")
                    .font(.caption)
                    .foregroundStyle(.liquidLava)
                    .tracking(1.5)

                if let section = article.section {
                    Text("·")
                        .foregroundStyle(.dustyGrey)
                    Text(section.uppercased())
                        .font(.caption)
                        .foregroundStyle(.dustyGrey)
                        .tracking(1.2)
                }
            }
            .cascadeIn(delay: 0.08, appeared: appeared)

            Text(article.title)
                .font(.headline1)
                .foregroundStyle(.primaryText)
                .cascadeIn(delay: 0.14, appeared: appeared)

            HStack(spacing: 16) {
                if let author = article.author {
                    Label(author, systemImage: "person.fill")
                        .font(.bodySmall)
                        .foregroundStyle(.dustyGrey)
                }

                if let date = article.publishDate {
                    Label(date.timeAgoDisplay, systemImage: "clock")
                        .font(.bodySmall)
                        .foregroundStyle(.dustyGrey)
                }

                if let score = article.score {
                    Label("\(score)", systemImage: "arrow.up")
                        .font(.bodySmall)
                        .foregroundStyle(.dustyGrey)
                }

                if let comments = article.commentCount {
                    Label("\(comments)", systemImage: "bubble.right")
                        .font(.bodySmall)
                        .foregroundStyle(.dustyGrey)
                }
            }
            .cascadeIn(delay: 0.2, appeared: appeared)

            if !article.topics.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(article.topics, id: \.self) { topic in
                        Text(topic)
                            .font(.caption)
                            .foregroundStyle(.liquidLava)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.liquidLava.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                .cascadeIn(delay: 0.26, appeared: appeared)
            }
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        if viewModel.isLoading {
            ProgressView()
                .tint(.liquidLava)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else if let content = viewModel.fullContent {
            if article.articleSource == .wikipedia {
                WikipediaWebView(
                    htmlContent: content,
                    dynamicHeight: $webViewHeight,
                    onLinkTap: { url in
                        handleLinkTap(url)
                    }
                )
                .frame(height: webViewHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                HTMLTextView(htmlContent: content)
            }
        } else if let errorMsg = viewModel.errorMessage {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32))
                    .foregroundStyle(.dustyGrey)
                Text(errorMsg)
                    .font(.bodyMedium)
                    .foregroundStyle(.secondaryText)
                    .multilineTextAlignment(.center)
                Button("Try Again") {
                    Task { await viewModel.loadFullArticle(for: article) }
                }
                .font(.label)
                .foregroundStyle(.liquidLava)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else if !article.summary.isEmpty {
            Text(article.summary)
                .font(.bodyLarge)
                .foregroundStyle(.primaryText)
                .lineSpacing(6)
        }
    }

    private func handleLinkTap(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else { return }

        if depth >= Self.maxDepth {
            safariURL = IdentifiableURL(url: url)
            return
        }

        guard let title = Self.extractWikipediaTitle(from: url) else {
            safariURL = IdentifiableURL(url: url)
            return
        }

        let decoded = (title.removingPercentEncoding ?? title)
            .replacingOccurrences(of: "_", with: " ")
        let pageURL = "https://en.wikipedia.org/wiki/\(title)"
        linkedPage = WikiLink(title: decoded, pageURL: pageURL, section: article.section)
    }

    private static func extractWikipediaTitle(from url: URL) -> String? {
        let host = url.host?.lowercased() ?? ""
        let isWikipedia = host == "en.wikipedia.org" || host == "en.m.wikipedia.org"

        guard isWikipedia || host.isEmpty else {
            return nil
        }

        let pathComponents = url.pathComponents

        var title: String?
        if let wikiIndex = pathComponents.firstIndex(of: "wiki"),
           wikiIndex + 1 < pathComponents.count {
            title = pathComponents[(wikiIndex + 1)...].joined(separator: "/")
        }

        guard let extracted = title, !extracted.isEmpty else {
            return nil
        }

        if extracted.contains(":") {
            let prefix = extracted.components(separatedBy: ":").first ?? ""
            let specialNamespaces = ["Special", "File", "Category", "Help", "Talk",
                                     "Wikipedia", "Template", "User", "Portal"]
            if specialNamespaces.contains(prefix) {
                return nil
            }
        }

        return extracted
    }
}

struct HTMLTextView: View {
    let htmlContent: String
    @State private var attributed: AttributedString?

    var body: some View {
        Group {
            if let attributed {
                Text(attributed)
            } else {
                Text(htmlContent)
            }
        }
        .font(.bodyLarge)
        .foregroundStyle(.primaryText)
        .lineSpacing(6)
        .task(id: htmlContent) {
            let cleaned = htmlContent.strippingHTML
            attributed = AttributedString(cleaned)
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}
