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

    private var appearances: [NewsItem] { store.items(mentioning: handle) }

    var body: some View {
        ZStack {
            BreezeBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if let profile {
                        ProfileHeader(profile: profile)
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
                            ProfilePostCard(post: post)
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
}

private struct ProfileHeader: View {
    let profile: XPublicProfile

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
                    Text(verbatim: profile.biography)
                        .font(.subheadline)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
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
                    NavigationLink {
                        NativeLinkDestinationView(url: websiteURL, contextItem: profileContextItem)
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

    private var profileContextItem: NewsItem {
        let source = NewsSource(
            id: "profile-\(profile.handle.lowercased())",
            name: profile.name,
            handle: profile.handle,
            kind: .x,
            isOfficial: false,
            symbol: "person.crop.circle.fill"
        )
        return NewsItem(
            id: "profile-link:\(profile.handle)",
            source: source,
            title: profile.name,
            body: profile.biography,
            category: "@\(profile.handle)",
            articleURL: profile.websiteURL,
            imageURL: profile.bannerURL,
            publishedAt: .now,
            metrics: nil
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: post.text)
                .font(.subheadline)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            HStack(spacing: 14) {
                Label(post.replies.formatted(.number.notation(.compactName)), systemImage: "bubble.left")
                Label(post.reposts.formatted(.number.notation(.compactName)), systemImage: "arrow.2.squarepath")
                Label(post.likes.formatted(.number.notation(.compactName)), systemImage: "heart")
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

    var body: some View {
        Group {
            if RobloxCatalogService.isCatalogURL(url) {
                RobloxCatalogLinkView(url: url, contextItem: contextItem)
            } else {
                CompanionContentView(item: contextItem.withArticleURL(url))
            }
        }
        .navigationTitle(url.host?.replacingOccurrences(of: "www.", with: "") ?? "Linked source")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RobloxCatalogLinkView: View {
    let url: URL
    let contextItem: NewsItem
    @State private var catalogItem: RobloxCatalogItem?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            BreezeBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label("Roblox catalog", systemImage: "cube.fill")
                        .font(.headline)
                        .foregroundStyle(Color.breezeMint)

                    if let imageURL = catalogItem?.thumbnailURL ?? contextItem.imageURL {
                        RemoteMediaImage(url: imageURL, maxHeight: 380)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        if isLoading {
                            ProgressView("Checking Roblox item details...")
                        } else if let catalogItem {
                            Text(verbatim: catalogItem.name)
                                .font(.title2.bold())
                            if let creatorName = catalogItem.creatorName {
                                HStack(spacing: 5) {
                                    Text("By \(creatorName)")
                                    if catalogItem.creatorIsVerified {
                                        Image(systemName: "checkmark.seal.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            }
                            if let description = catalogItem.description {
                                Text(verbatim: description)
                                    .lineSpacing(5)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            HStack(spacing: 16) {
                                Label("ID \(catalogItem.id)", systemImage: "number")
                                if let price = catalogItem.price, catalogItem.isForSale == true {
                                    Label("\(price) Robux", systemImage: "hexagon.fill")
                                } else if catalogItem.isForSale == false {
                                    Label("Not currently for sale", systemImage: "clock")
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .breezeGlass(cornerRadius: 24, tint: Color.breezeMint.opacity(0.07))

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
    }
}
