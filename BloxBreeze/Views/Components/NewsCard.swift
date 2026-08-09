import SwiftUI

struct NewsCard: View {
    @EnvironmentObject private var store: NewsStore
    let item: NewsItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let imageURL = item.imageURL {
                ZStack {
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

                    if looksLikeVideo {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 52, height: 52)
                            .overlay {
                                Image(systemName: "play.fill")
                                    .font(.headline.bold())
                                    .foregroundStyle(.white)
                                    .offset(x: 1)
                            }
                    }
                }
                .frame(height: 156)
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
                    .fixedSize(horizontal: false, vertical: true)

                if let cardSummary {
                    Text(verbatim: cardSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private var cardSummary: String? {
        guard item.isFromX else { return nil }
        let paragraphs = item.body
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard paragraphs.count > 1 else { return nil }
        let remainder = paragraphs.dropFirst().joined(separator: "\n\n")
        return remainder.isEmpty ? nil : remainder
    }

    private var looksLikeVideo: Bool {
        guard let value = item.imageURL?.absoluteString.lowercased() else { return false }
        return value.contains("video_thumb") || value.contains("amplify_video_thumb")
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
