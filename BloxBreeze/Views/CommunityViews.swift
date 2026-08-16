import SwiftUI
import UIKit

struct ContentEntitySheet: View {
    @Environment(\.dismiss) private var dismiss
    let route: ContentEntityRoute
    let contextItem: NewsItem

    var body: some View {
        NavigationStack {
            Group {
                switch route {
                case let .profile(handle):
                    MentionProfileView(handle: handle)
                case let .hashtag(tag):
                    HashtagDetailView(tag: tag)
                case let .link(url):
                    NativeLinkDestinationView(url: url, contextItem: contextItem)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", systemImage: "xmark") { dismiss() }
                        .accessibilityLabel("Close")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

struct HashtagGardenView: View {
    @EnvironmentObject private var store: NewsStore
    @State private var searchText = ""

    private var displayedStats: [HashtagStat] {
        guard !searchText.isEmpty else { return store.hashtagStats }
        return store.hashtagStats.filter {
            $0.tag.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            BreezeBackground()
            ScrollView {
                LazyVStack(spacing: 14) {
                    HashtagGardenHeader(stats: store.hashtagStats)

                    if displayedStats.isEmpty {
                        ContentUnavailableView(
                            searchText.isEmpty ? "No hashtags yet" : "No matching hashtag",
                            systemImage: "number",
                            description: Text("Hashtags bloom here as they appear in downloaded posts and thread replies.")
                        )
                        .padding(.top, 36)
                    } else {
                        ForEach(displayedStats) { stat in
                            NavigationLink {
                                HashtagDetailView(tag: stat.tag)
                            } label: {
                                HashtagStatCard(stat: stat)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 90)
            }
        }
        .navigationTitle("Hashtag Garden")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Find a hashtag")
    }
}

private struct HashtagGardenHeader: View {
    let stats: [HashtagStat]

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "number.circle.fill")
                .font(.system(size: 38))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.breezeLavender, Color.breezePeach)
            VStack(alignment: .leading, spacing: 4) {
                Text("Community pulse")
                    .font(.title3.bold())
                Text("\(stats.count) unique tags across \(stats.reduce(0) { $0 + $1.postCount }) tagged posts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .breezeGlass(cornerRadius: 26, tint: Color.breezeLavender.opacity(0.10))
    }
}

private struct HashtagStatCard: View {
    let stat: HashtagStat

    var body: some View {
        HStack(spacing: 14) {
            Text("#")
                .font(.title2.bold())
                .foregroundStyle(Color.breezeLavender)
                .frame(width: 48, height: 48)
                .glassEffect(
                    .regular.tint(Color.breezeLavender.opacity(0.14)).interactive(),
                    in: Circle()
                )
            VStack(alignment: .leading, spacing: 4) {
                Text("#\(stat.tag)")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("\(stat.postCount) posts · \(stat.storyCount) stories · \(stat.sourceCount) sources")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .contentShape(.rect(cornerRadius: 22))
        .breezeGlass(cornerRadius: 22, tint: Color.breezeLavender.opacity(0.055), interactive: true)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows every downloaded story using this hashtag")
    }
}

struct HashtagDetailView: View {
    @EnvironmentObject private var store: NewsStore
    let tag: String

    private var matchingItems: [NewsItem] { store.items(matchingHashtag: tag) }
    private var stat: HashtagStat? {
        store.hashtagStats.first { $0.tag.caseInsensitiveCompare(tag) == .orderedSame }
    }

    var body: some View {
        ZStack {
            BreezeBackground()
            ScrollView {
                LazyVStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("#\(tag)")
                            .font(.largeTitle.bold())
                            .foregroundStyle(Color.breezeLavender)
                        if let stat {
                            Text("Seen in \(stat.postCount) posts across \(stat.storyCount) stories from \(stat.sourceCount) sources.")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("This tag is not in the current downloaded feed.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .breezeGlass(cornerRadius: 26, tint: Color.breezeLavender.opacity(0.10))

                    ForEach(matchingItems) { item in
                        NavigationLink {
                            ArticleDetailView(item: item)
                        } label: {
                            HashtagStoryRow(item: item, tag: tag)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .padding(.bottom, 90)
            }
        }
        .navigationTitle("Hashtag")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HashtagStoryRow: View {
    let item: NewsItem
    let tag: String

    private var excerpt: String {
        item.allPostTexts.first { text in
            PostEntityExtractor.hashtags(in: text).contains {
                $0.caseInsensitiveCompare(tag) == .orderedSame
            }
        } ?? item.body
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SourceBadge(source: item.source)
                Spacer()
                Text(item.publishedAt.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Text(verbatim: excerpt)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
            Label("Open native story", systemImage: "arrow.right.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(item.source.tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .contentShape(.rect(cornerRadius: 22))
        .breezeGlass(cornerRadius: 22, tint: item.source.tint.opacity(0.055), interactive: true)
    }
}

struct MentionProfileView: View {
    @EnvironmentObject private var store: NewsStore
    let handle: String
    @State private var profile: XPublicProfile?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var nestedEntityRoute: ContentEntityRoute?

    private var appearances: [NewsItem] { store.items(mentioning: handle) }

    var body: some View {
        ZStack {
            BreezeBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if let profile {
                        ProfileHeader(profile: profile) { nestedEntityRoute = $0 }
                        ProfileStats(profile: profile)
                    } else {
                        ProfileFallbackHeader(handle: handle, isLoading: isLoading)
                    }

                    MentionAppearancesCard(
                        handle: handle,
                        postCount: store.mentionPostCount(handle: handle),
                        items: appearances
                    )

                    if let profile, !profile.recentPosts.isEmpty {
                        Label("Recent public posts", systemImage: "clock.arrow.circlepath")
                            .font(.headline)
                            .foregroundStyle(Color.breezeLavender)
                        ForEach(profile.recentPosts) { post in
                            ProfilePostCard(post: post) { nestedEntityRoute = $0 }
                        }
                    } else if isLoading {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Gathering the public profile and recent posts...")
                                .foregroundStyle(.secondary)
                        }
                        .padding(18)
                        .breezeGlass(cornerRadius: 22)
                    } else if let errorMessage {
                        Label(errorMessage, systemImage: "wifi.exclamationmark")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(16)
                            .breezeGlass(cornerRadius: 22, tint: Color.breezePeach.opacity(0.08))
                    }

                    Label(
                        "Free keyless public profile · viewed entirely inside BloxBreeze",
                        systemImage: "lock.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .breezeGlass(cornerRadius: 18)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .padding(.bottom, 90)
            }
        }
        .navigationTitle("@\(handle)")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: handle.lowercased()) { await load() }
        .sheet(item: $nestedEntityRoute) { route in
            AnyView(ContentEntitySheet(route: route, contextItem: profileContextItem))
        }
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            profile = try await XProfileService().fetch(handle: handle)
        } catch is CancellationError {
            return
        } catch {
            profile = nil
            errorMessage = "Live profile details are resting right now; local mention history is still available."
        }
        isLoading = false
    }

    private var profileContextItem: NewsItem {
        let shownName = profile?.name ?? "@\(handle)"
        let shownHandle = profile?.handle ?? handle
        let source = NewsSource(
            id: "profile-\(shownHandle.lowercased())",
            name: shownName,
            handle: shownHandle,
            kind: .x,
            isOfficial: false,
            symbol: "person.crop.circle.fill"
        )
        return NewsItem(
            id: "profile-link:\(shownHandle)",
            source: source,
            title: shownName,
            body: profile?.biography ?? "Public profile for @\(shownHandle)",
            category: "@\(shownHandle)",
            articleURL: profile?.websiteURL,
            imageURL: profile?.bannerURL,
            publishedAt: .now,
            metrics: nil
        )
    }
}

private struct ProfileHeader: View {
    let profile: XPublicProfile
    let onOpen: (ContentEntityRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let bannerURL = profile.bannerURL {
                    HighQualityAsyncImage(url: bannerURL) { phase in
                        if case let .success(image) = phase {
                            NativeUIImageView(image: image, contentMode: .scaleAspectFill)
                        } else {
                            profileGradient
                        }
                    }
                } else {
                    profileGradient
                }
            }
            .frame(height: 138)
            .clipped()

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .bottom, spacing: 14) {
                    ProfileAvatar(url: profile.avatarURL, name: profile.name)
                        .offset(y: -28)
                        .padding(.bottom, -28)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(verbatim: profile.name)
                                .font(.title2.bold())
                            if profile.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.blue)
                                    .accessibilityLabel("Verified public profile")
                            }
                        }
                        Text("@\(profile.handle)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                if !profile.biography.isEmpty {
                    InteractivePostText(
                        text: profile.biography,
                        font: .subheadline,
                        lineSpacing: 4,
                        onOpen: onOpen
                    )
                }

                HStack(spacing: 14) {
                    if let location = profile.location {
                        Label(location, systemImage: "mappin.and.ellipse")
                    }
                    if let joinedAt = profile.joinedAt {
                        Label("Joined \(joinedAt.formatted(.dateTime.month(.wide).year()))", systemImage: "calendar")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let websiteURL = profile.websiteURL,
                   let label = profile.websiteLabel ?? websiteURL.host {
                    Button {
                        onOpen(.link(websiteURL))
                    } label: {
                        Label(label, systemImage: "link")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens this website in BloxBreeze's native reader")
                }
            }
            .padding(18)
        }
        .clipShape(.rect(cornerRadius: 28))
        .breezeGlass(cornerRadius: 28, tint: Color.breezeLavender.opacity(0.08))
    }

    private var profileGradient: some View {
        LinearGradient(
            colors: [Color.breezeLavender.opacity(0.55), Color.breezeCoral.opacity(0.35)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct ProfileAvatar: View {
    let url: URL?
    let name: String

    var body: some View {
        Group {
            if let url {
                HighQualityAsyncImage(url: url) { phase in
                    if case let .success(image) = phase {
                        NativeUIImageView(image: image, contentMode: .scaleAspectFill)
                    } else {
                        avatarFallback
                    }
                }
            } else {
                avatarFallback
            }
        }
        .frame(width: 82, height: 82)
        .background(Color(uiColor: .systemBackground))
        .clipShape(Circle())
        .overlay(Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 4))
        .glassEffect(.regular.tint(Color.breezeLavender.opacity(0.08)), in: Circle())
    }

    private var avatarFallback: some View {
        Text(String(name.prefix(1)).uppercased())
            .font(.title.bold())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.breezeLavender.opacity(0.20))
    }
}

private struct ProfileFallbackHeader: View {
    let handle: String
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 16) {
            ProfileAvatar(url: nil, name: handle)
            VStack(alignment: .leading, spacing: 5) {
                Text("@\(handle)")
                    .font(.title2.bold())
                Text(isLoading ? "Preparing public profile..." : "Mention profile")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(18)
        .breezeGlass(cornerRadius: 26, tint: Color.breezeLavender.opacity(0.08))
    }
}

private struct ProfileStats: View {
    let profile: XPublicProfile

    var body: some View {
        HStack(spacing: 0) {
            stat(profile.followers, label: "Followers")
            Divider().frame(height: 34)
            stat(profile.following, label: "Following")
            Divider().frame(height: 34)
            stat(profile.postCount, label: "Posts")
        }
        .padding(.vertical, 14)
        .breezeGlass(cornerRadius: 22, tint: Color.breezeMint.opacity(0.055))
    }

    private func stat(_ value: Int, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value.formatted(.number.notation(.compactName)))
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MentionAppearancesCard: View {
    let handle: String
    let postCount: Int
    let items: [NewsItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("BloxBreeze mentions", systemImage: "at.circle.fill")
                .font(.headline)
                .foregroundStyle(Color.breezeCoral)
            Text("@\(handle) appears in \(postCount) downloaded posts across \(items.count) stories.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(items.prefix(4)) { item in
                NavigationLink {
                    ArticleDetailView(item: item)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.source.symbol)
                            .foregroundStyle(item.source.tint)
                        Text(item.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(2)
                            .foregroundStyle(.primary)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.caption2.bold())
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .breezeGlass(cornerRadius: 16, tint: item.source.tint.opacity(0.045), interactive: true)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .breezeGlass(cornerRadius: 24, tint: Color.breezeCoral.opacity(0.055))
    }
}

private struct ProfilePostCard: View {
    let post: XProfilePost
    let onOpen: (ContentEntityRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            InteractivePostText(
                text: post.text,
                font: .subheadline,
                lineSpacing: 4,
                onOpen: onOpen
            )
            HStack(spacing: 14) {
                Label(post.replies.formatted(.number.notation(.compactName)), systemImage: "bubble.left")
                Label(post.reposts.formatted(.number.notation(.compactName)), systemImage: "arrow.2.squarepath")
                Label(post.likes.formatted(.number.notation(.compactName)), systemImage: "heart")
                if let views = post.views {
                    Label(views.formatted(.number.notation(.compactName)), systemImage: "eye")
                }
                Spacer()
                Text(post.publishedAt.formatted(.relative(presentation: .named)))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .breezeGlass(cornerRadius: 22, tint: Color.breezeLavender.opacity(0.045))
    }
}

struct NativeLinkDestinationView: View {
    let url: URL
    let contextItem: NewsItem

    private var resolvedURL: URL { NativeLinkResolver.secure(url) }

    var body: some View {
        Group {
            if RobloxCatalogService.isCatalogURL(resolvedURL) {
                RobloxCatalogLinkView(url: resolvedURL, contextItem: contextItem)
            } else if RobloxMarketplaceService.isMarketplaceURL(resolvedURL) {
                RobloxMarketplaceLinkView(url: resolvedURL, contextItem: contextItem)
            } else {
                CompanionContentView(item: contextItem.withArticleURL(resolvedURL))
            }
        }
        .navigationTitle(resolvedURL.host?.replacingOccurrences(of: "www.", with: "") ?? "Linked source")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RobloxMarketplaceLinkView: View {
    let url: URL
    let contextItem: NewsItem
    @State private var collection: RobloxMarketplaceCollection?
    @State private var isLoading = true

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack {
            BreezeBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Roblox Marketplace", systemImage: "storefront.fill")
                            .font(.title2.bold())
                            .foregroundStyle(Color.breezeMint)
                        Text("A live, native preview of the shared Marketplace collection.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let labels = collection?.filterLabels, !labels.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(labels, id: \.self) { label in
                                        Text(verbatim: label)
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 11)
                                            .padding(.vertical, 7)
                                            .glassEffect(
                                                .regular.tint(Color.breezeMint.opacity(0.10)),
                                                in: .capsule
                                            )
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .breezeGlass(cornerRadius: 26, tint: Color.breezeMint.opacity(0.08))

                    if isLoading {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Gathering current Marketplace items...")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(20)
                        .breezeGlass(cornerRadius: 22)
                    } else if let collection, !collection.items.isEmpty {
                        if let note = collection.note {
                            Label(note, systemImage: "info.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(14)
                                .breezeGlass(cornerRadius: 18, tint: Color.breezeLavender.opacity(0.055))
                        }

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(collection.items) { item in
                                NavigationLink {
                                    RobloxCatalogLinkView(
                                        url: item.catalogURL,
                                        contextItem: contextItem.withArticleURL(item.catalogURL)
                                    )
                                } label: {
                                    MarketplacePreviewCard(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        ContentUnavailableView(
                            "Marketplace preview is resting",
                            systemImage: "storefront",
                            description: Text("The shared Roblox address is still preserved below.")
                        )
                        .padding(18)
                        .breezeGlass(cornerRadius: 24, tint: Color.breezePeach.opacity(0.07))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Original address")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(verbatim: url.absoluteString)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.blue)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Button {
                            UIPasteboard.general.url = url
                        } label: {
                            Label("Copy Marketplace address", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                    }
                    .padding(18)
                    .breezeGlass(cornerRadius: 24, tint: Color.breezeLavender.opacity(0.06))

                    Label("Live public Roblox data · no browser or login", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(14)
                        .breezeGlass(cornerRadius: 18)
                }
                .padding(16)
                .padding(.bottom, 90)
            }
        }
        .task(id: url) {
            isLoading = true
            collection = await RobloxMarketplaceService().fetch(url: url)
            isLoading = false
        }
    }
}

private struct MarketplacePreviewCard: View {
    let item: RobloxMarketplacePreview

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if let thumbnailURL = item.thumbnailURL {
                    HighQualityAsyncImage(url: thumbnailURL) { phase in
                        if case let .success(image) = phase {
                            NativeUIImageView(image: image, contentMode: .scaleAspectFit)
                        } else {
                            previewPlaceholder
                        }
                    }
                } else {
                    previewPlaceholder
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 150)
            .background(Color(uiColor: .secondarySystemBackground).opacity(0.65))
            .clipShape(.rect(cornerRadius: 17))

            Text(verbatim: item.name)
                .font(.subheadline.bold())
                .lineLimit(2)
                .foregroundStyle(.primary)

            if let creatorName = item.creatorName {
                HStack(spacing: 4) {
                    Text("By \(creatorName)")
                        .lineLimit(1)
                    if item.creatorIsVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.blue)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 5) {
                Image(systemName: item.isCollectible ? "sparkles" : "hexagon.fill")
                Text(verbatim: item.marketLabel)
                    .lineLimit(1)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.breezeMint)

            HStack(spacing: 8) {
                if let taxonomyName = item.taxonomyName {
                    Text(verbatim: taxonomyName)
                        .lineLimit(1)
                }
                if let favoriteCount = item.favoriteCount {
                    Label(favoriteCount.formatted(.number.notation(.compactName)), systemImage: "heart")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 250, alignment: .topLeading)
        .padding(12)
        .contentShape(.rect(cornerRadius: 22))
        .breezeGlass(cornerRadius: 22, tint: Color.breezeMint.opacity(0.05), interactive: true)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens live Roblox item details inside BloxBreeze")
    }

    private var previewPlaceholder: some View {
        Image(systemName: "cube.transparent.fill")
            .font(.system(size: 42))
            .foregroundStyle(Color.breezeMint.opacity(0.75))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct RobloxCatalogLinkView: View {
    let url: URL
    let contextItem: NewsItem
    @State private var catalogItem: RobloxCatalogItem?
    @State private var isLoading = true
    @State private var selectedImage: ZoomableImageItem?

    var body: some View {
        ZStack {
            BreezeBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label("Roblox catalog", systemImage: "cube.fill")
                        .font(.headline)
                        .foregroundStyle(Color.breezeMint)

                    if let imageURL = catalogItem?.thumbnailURL ?? contextItem.imageURL {
                        RemoteMediaImage(url: imageURL, maxHeight: 390) {
                            selectedImage = ZoomableImageItem(url: imageURL)
                        }
                    }

                    if isLoading {
                        ProgressView("Checking Roblox item details...")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .breezeGlass(cornerRadius: 24, tint: Color.breezeMint.opacity(0.07))
                    } else if let catalogItem {
                        CatalogIdentityCard(item: catalogItem)
                        CatalogMarketCard(item: catalogItem)
                        CatalogFactsCard(item: catalogItem)
                    } else {
                        ContentUnavailableView(
                            "Item details are resting",
                            systemImage: "cube.transparent",
                            description: Text("The original address is preserved below so nothing gets lost.")
                        )
                        .padding(18)
                        .breezeGlass(cornerRadius: 24, tint: Color.breezePeach.opacity(0.07))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Original address")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(verbatim: url.absoluteString)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.blue)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Button {
                            UIPasteboard.general.url = url
                        } label: {
                            Label("Copy Roblox address", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)

                        if let catalogItem {
                            Button {
                                UIPasteboard.general.string = catalogItem.copySummary(sourceURL: url)
                            } label: {
                                Label("Copy item summary", systemImage: "text.page.badge.magnifyingglass")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.glass)
                        }
                    }
                    .padding(18)
                    .breezeGlass(cornerRadius: 24, tint: Color.breezeLavender.opacity(0.06))

                    Label("Native Roblox details · no browser or redirect", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(14)
                        .breezeGlass(cornerRadius: 18)
                }
                .padding(16)
                .padding(.bottom, 90)
            }
        }
        .task(id: url) {
            isLoading = true
            catalogItem = await RobloxCatalogService().fetch(url: url)
            isLoading = false
        }
        .fullScreenCover(item: $selectedImage) { image in
            FullScreenImageViewer(item: image)
        }
    }
}

private struct CatalogIdentityCard: View {
    let item: RobloxCatalogItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: item.name)
                    .font(.title2.bold())
                Spacer(minLength: 8)
                if item.isLimited {
                    Label(item.isLimitedUnique ? "Limited U" : "Limited", systemImage: "sparkles")
                        .font(.caption.bold())
                        .foregroundStyle(Color.breezePeach)
                }
            }

            if let creatorName = item.creatorName {
                HStack(spacing: 5) {
                    Text("By \(creatorName)")
                    if item.creatorIsVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.blue)
                            .accessibilityLabel("Verified creator")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if let description = item.description {
                Text(verbatim: description)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }

            HStack(spacing: 7) {
                Image(systemName: "number")
                Text(verbatim: String(item.id))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .accessibilityLabel("Asset ID \(String(item.id))")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .breezeGlass(cornerRadius: 24, tint: Color.breezeMint.opacity(0.07))
    }
}

private struct CatalogMarketCard: View {
    let item: RobloxCatalogItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Marketplace", systemImage: "bag.fill")
                .font(.headline)
                .foregroundStyle(Color.breezeMint)

            availability

            HStack(spacing: 10) {
                if let favorites = item.favoriteCount {
                    CatalogMetric(
                        value: favorites.formatted(.number.notation(.compactName)),
                        label: "Favorites",
                        symbol: "heart.fill"
                    )
                }
                if let quantity = item.totalQuantity {
                    CatalogMetric(
                        value: quantity.formatted(.number.notation(.compactName)),
                        label: "Created",
                        symbol: "shippingbox.fill"
                    )
                } else if let sales = item.sales {
                    CatalogMetric(
                        value: sales.formatted(.number.notation(.compactName)),
                        label: "Sales",
                        symbol: "chart.bar.fill"
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .breezeGlass(cornerRadius: 24, tint: Color.breezeMint.opacity(0.065))
    }

    @ViewBuilder
    private var availability: some View {
        switch item.availability {
        case let .resale(lowestPrice):
            VStack(alignment: .leading, spacing: 4) {
                Label("Lowest resale", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("\(lowestPrice.formatted()) Robux")
                    .font(.title3.bold())
                Text("The original drop ended, but Roblox currently reports a collectible resale listing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case let .forSale(price):
            Label(
                price.map { "\($0.formatted()) Robux" } ?? "Available on Roblox",
                systemImage: "hexagon.fill"
            )
            .font(.title3.bold())
        case .free:
            Label("Free", systemImage: "gift.fill")
                .font(.title3.bold())
        case .offSale:
            Label("Off sale", systemImage: "clock")
                .font(.title3.bold())
        case .unknown:
            Label("Availability unavailable", systemImage: "questionmark.circle")
                .font(.subheadline.weight(.semibold))
        }
    }
}

private struct CatalogMetric: View {
    let value: String
    let label: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(value, systemImage: symbol)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .breezeGlass(cornerRadius: 17, tint: Color.breezeLavender.opacity(0.045))
    }
}

private struct CatalogFactsCard: View {
    let item: RobloxCatalogItem

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label("Item details", systemImage: "info.circle.fill")
                .font(.headline)
                .foregroundStyle(Color.breezeLavender)

            if let type = item.assetTypeName ?? item.productType {
                fact("Type", value: type, symbol: "tshirt.fill")
            }
            if let createdAt = item.createdAt {
                fact("Created", value: createdAt.formatted(date: .abbreviated, time: .omitted), symbol: "calendar.badge.plus")
            }
            if let updatedAt = item.updatedAt {
                fact("Updated", value: updatedAt.formatted(date: .abbreviated, time: .omitted), symbol: "clock.arrow.circlepath")
            }
            if let remaining = item.remaining, remaining > 0 {
                fact("Remaining", value: remaining.formatted(), symbol: "hourglass")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .breezeGlass(cornerRadius: 24, tint: Color.breezeLavender.opacity(0.055))
    }

    private func fact(_ label: String, value: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(Color.breezeLavender)
                .frame(width: 22)
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(verbatim: value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

private extension RobloxCatalogItem {
    func copySummary(sourceURL: URL) -> String {
        var lines = [name]
        if let creatorName { lines.append("By \(creatorName)") }
        switch availability {
        case let .resale(lowestPrice): lines.append("Lowest resale: \(lowestPrice.formatted()) Robux")
        case let .forSale(price): lines.append(price.map { "Price: \($0.formatted()) Robux" } ?? "Available")
        case .free: lines.append("Free")
        case .offSale: lines.append("Off sale")
        case .unknown: break
        }
        lines.append("Asset ID: \(String(id))")
        lines.append(sourceURL.absoluteString)
        return lines.joined(separator: "\n")
    }
}
