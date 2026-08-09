import SwiftUI

struct NewsCard: View {
    @EnvironmentObject private var store: NewsStore
    let item: NewsItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let imageURL = item.imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case let .success(image):
                        image.resizable().scaledToFill()
                    case .failure:
                        imagePlaceholder
                    default:
                        ZStack {
                            imagePlaceholder
                            ProgressView()
                        }
                    }
                }
                .frame(height: 176)
                .frame(maxWidth: .infinity)
                .clipped()
            }

            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 8) {
                    SourceBadge(source: item.source)
                    Spacer()
                    if store.savedIDs.contains(item.id) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(Color.breezeCoral)
                            .accessibilityLabel("Saved")
                    }
                    if !store.readIDs.contains(item.id) {
                        Circle()
                            .fill(item.source.tint)
                            .frame(width: 7, height: 7)
                            .accessibilityLabel("Unread")
                    }
                }

                Text(item.title)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)

                if item.isFromX {
                    Text(item.body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }

                HStack(spacing: 12) {
                    Text(item.publishedAt.formatted(.relative(presentation: .named)))
                    Label("\(item.readingTime) min", systemImage: "book.pages")
                    if let metrics = item.metrics {
                        Label(metrics.likes.formatted(.number.notation(.compactName)), systemImage: "heart")
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
            .padding(16)
        }
        .background(.clear)
        .clipShape(.rect(cornerRadius: 26))
        .breezeGlass(cornerRadius: 26, tint: item.source.tint.opacity(0.055), interactive: true)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the story inside BloxBreeze")
    }

    private var imagePlaceholder: some View {
        LinearGradient(
            colors: [item.source.tint.opacity(0.44), item.source.tint.opacity(0.12)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: item.source.symbol)
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

struct SourceBadge: View {
    let source: NewsSource

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: source.symbol)
            Text(source.name)
            if source.isOfficial {
                Image(systemName: "checkmark.circle.fill")
                    .accessibilityLabel("Official Roblox source")
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(source.tint)
    }
}
