import SwiftUI

struct NewsCard: View {
    @EnvironmentObject private var store: NewsStore
    let item: NewsItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let imageURL = item.imageURL {
                GeometryReader { proxy in
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
                        .frame(width: proxy.size.width, height: 156)
                        .clipped()

                        if looksLikeVideo {
                            Image(systemName: "play.fill")
                                .font(.headline.bold())
                                .foregroundStyle(.white)
                                .offset(x: 1)
                                .frame(width: 52, height: 52)
                                .glassEffect(
                                    .regular.tint(.black.opacity(0.22)),
                                    in: Circle()
                                )
                        }
                    }
                    .frame(width: proxy.size.width, height: 156)
                    .clipped()
                }
                .frame(height: 156)
                .frame(maxWidth: .infinity)
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
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

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
        .contentShape(.rect)
        .clipShape(.rect(cornerRadius: 26))
        .breezeGlass(cornerRadius: 26, tint: item.source.tint.opacity(0.055))
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
        item.hasVideoPreview
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
