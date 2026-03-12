import SwiftUI

struct StoryCardView: View {
    let article: Article
    let rank: Int?

    init(article: Article, rank: Int? = nil) {
        self.article = article
        self.rank = rank
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let rank {
                Text("\(rank)")
                    .font(AppFont.bold(20))
                    .foregroundStyle(.liquidLava)
                    .frame(width: 32, alignment: .center)
                    .padding(.top, 2)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(article.title)
                    .font(.headline3)
                    .foregroundStyle(.primaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !article.summary.isEmpty {
                    Text(article.summary)
                        .font(.bodySmall)
                        .foregroundStyle(.liquidLava.opacity(0.7))
                        .lineLimit(1)
                }

                HStack(spacing: 16) {
                    if let score = article.score {
                        Label("\(score.abbreviated)", systemImage: "arrow.up")
                            .font(.caption)
                            .foregroundStyle(.dustyGrey)
                    }

                    if let comments = article.commentCount {
                        Label("\(comments.abbreviated)", systemImage: "bubble.right")
                            .font(.caption)
                            .foregroundStyle(.dustyGrey)
                    }

                    if let author = article.author {
                        Label(author, systemImage: "person")
                            .font(.caption)
                            .foregroundStyle(.dustyGrey)
                            .lineLimit(1)
                    }

                    if let date = article.publishDate {
                        Text(date.timeAgoDisplay)
                            .font(.caption)
                            .foregroundStyle(.dustyGrey)
                    }
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "arrow.up.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.dustyGrey.opacity(0.5))
                .padding(.top, 4)
        }
        .padding(16)
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
}
