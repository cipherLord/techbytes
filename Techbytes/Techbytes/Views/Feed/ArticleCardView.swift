import SwiftUI

struct ArticleCardView: View {
    let article: Article
    var onLike: (() -> Void)?
    var onDislike: (() -> Void)?
    var currentInteraction: InteractionType?
    var showInteractions: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let imageURL = article.imageURL, let url = URL(string: imageURL) {
                CachedAsyncImage(url: url, height: 180, maxPixelSize: 400)
            }

            VStack(alignment: .leading, spacing: 10) {
                if let section = article.section {
                    Text(section.uppercased())
                        .font(.caption)
                        .foregroundStyle(.liquidLava)
                        .tracking(1.2)
                }

                Text(article.title)
                    .font(.headline3)
                    .foregroundStyle(.primaryText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if !article.summary.isEmpty {
                    Text(article.summary)
                        .font(.bodyMedium)
                        .foregroundStyle(.secondaryText)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 12) {
                    if !article.topics.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(article.topics.prefix(2), id: \.self) { topic in
                                Text(topic)
                                    .font(.caption)
                                    .foregroundStyle(.liquidLava.opacity(0.9))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.liquidLava.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    Spacer()

                    if showInteractions && article.articleSource == .wikipedia {
                        interactionButtons
                    }
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
    private var interactionButtons: some View {
        HStack(spacing: 16) {
            Button {
                withAnimation(.spring(response: 0.3)) { onLike?() }
            } label: {
                Image(systemName: currentInteraction == .like ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .font(.system(size: 16))
                    .foregroundStyle(currentInteraction == .like ? .liquidLava : .dustyGrey)
                    .scaleEffect(currentInteraction == .like ? 1.15 : 1.0)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(flexibility: .soft), trigger: currentInteraction)
            .accessibilityLabel(currentInteraction == .like ? "Liked" : "Like")
            .accessibilityHint("Double-tap to like this article")

            Button {
                withAnimation(.spring(response: 0.3)) { onDislike?() }
            } label: {
                Image(systemName: currentInteraction == .dislike ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .font(.system(size: 16))
                    .foregroundStyle(currentInteraction == .dislike ? .dustyGrey : .dustyGrey.opacity(0.6))
                    .scaleEffect(currentInteraction == .dislike ? 1.15 : 1.0)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(currentInteraction == .dislike ? "Disliked" : "Dislike")
            .accessibilityHint("Double-tap to dislike this article")
        }
    }

    private var imagePlaceholder: some View {
        Color.slateGrey
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundStyle(.dustyGrey)
            )
    }
}

struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}
