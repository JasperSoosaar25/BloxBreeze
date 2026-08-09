import Foundation

struct XAPIService: Sendable {
    private let baseURL = URL(string: "https://api.x.com/2")!

    func validate(token: String) async throws {
        _ = try await lookupUsers(handles: ["Roblox_RTC"], token: token)
    }

    func fetch(token: String, sources: [NewsSource] = NewsSource.xSources) async throws -> [NewsItem] {
        let handles = sources.compactMap(\.handle)
        let users = try await lookupUsers(handles: handles, token: token)

        return try await withThrowingTaskGroup(of: [NewsItem].self) { group in
            for user in users {
                guard let source = NewsSource.source(forXHandle: user.username) else { continue }
                group.addTask {
                    try await posts(for: user, source: source, token: token)
                }
            }

            var combined: [NewsItem] = []
            for try await items in group {
                combined.append(contentsOf: items)
            }
            return combined.sorted { $0.publishedAt > $1.publishedAt }
        }
    }

    private func lookupUsers(handles: [String], token: String) async throws -> [XUser] {
        var components = URLComponents(url: baseURL.appending(path: "users/by"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "usernames", value: handles.joined(separator: ",")),
            URLQueryItem(name: "user.fields", value: "name,username,profile_image_url,verified,verified_type")
        ]
        let response: XUsersResponse = try await request(components.url!, token: token)
        if let data = response.data, !data.isEmpty { return data }
        throw FeedError.parsing(response.errors?.first?.detail ?? "X did not return the requested accounts.")
    }

    private func posts(for user: XUser, source: NewsSource, token: String) async throws -> [NewsItem] {
        var components = URLComponents(url: baseURL.appending(path: "users/\(user.id)/tweets"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "max_results", value: "20"),
            URLQueryItem(name: "exclude", value: "replies,retweets"),
            URLQueryItem(name: "tweet.fields", value: "created_at,attachments,entities,public_metrics,note_tweet"),
            URLQueryItem(name: "expansions", value: "attachments.media_keys"),
            URLQueryItem(name: "media.fields", value: "type,url,preview_image_url,width,height,alt_text")
        ]

        let response: XPostsResponse = try await request(components.url!, token: token)
        let mediaByKey = Dictionary(uniqueKeysWithValues: (response.includes?.media ?? []).map { ($0.mediaKey, $0) })

        return (response.data ?? []).map { post in
            let media = post.attachments?.mediaKeys.compactMap { mediaByKey[$0] }.first
            let text = post.noteTweet?.text ?? post.text
            let cleanText = Self.clean(text, entities: post.entities)
            let firstLine = cleanText.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? "Post by @\(user.username)"
            let title = firstLine.count > 92 ? String(firstLine.prefix(89)) + "…" : firstLine

            return NewsItem(
                id: "x:\(post.id)",
                source: source,
                title: title,
                body: cleanText,
                category: "@\(user.username)",
                articleURL: nil,
                imageURL: (media?.url ?? media?.previewImageURL).flatMap(URL.init(string:)),
                publishedAt: Self.date(from: post.createdAt) ?? .distantPast,
                metrics: post.publicMetrics.map {
                    NewsItem.Metrics(
                        replies: $0.replyCount,
                        reposts: $0.retweetCount,
                        likes: $0.likeCount,
                        views: $0.impressionCount
                    )
                }
            )
        }
    }

    private func request<Response: Decodable>(_ url: URL, token: String) async throws -> Response {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("Bearer \(token.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FeedError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let error = try? JSONDecoder().decode(XErrorEnvelope.self, from: data)
            throw FeedError.server(status: http.statusCode, message: error?.detail ?? error?.title)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Response.self, from: data)
    }

    private static func date(from string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let value = formatter.date(from: string) { return value }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private static func clean(_ text: String, entities: XEntities?) -> String {
        var result = text
        for url in entities?.urls ?? [] {
            let replacement = url.title ?? url.displayURL ?? ""
            result = result.replacingOccurrences(of: url.url, with: replacement)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct XUsersResponse: Decodable {
    let data: [XUser]?
    let errors: [XAPIError]?
}

private struct XUser: Decodable, Sendable {
    let id: String
    let name: String
    let username: String
    let profileImageURL: String?
    let verified: Bool?
    let verifiedType: String?
}

private struct XPostsResponse: Decodable {
    let data: [XPost]?
    let includes: XIncludes?
    let errors: [XAPIError]?
}

private struct XPost: Decodable {
    let id: String
    let text: String
    let createdAt: String?
    let attachments: XAttachments?
    let entities: XEntities?
    let publicMetrics: XPublicMetrics?
    let noteTweet: XNoteTweet?
}

private struct XAttachments: Decodable {
    let mediaKeys: [String]
}

private struct XIncludes: Decodable {
    let media: [XMedia]?
}

private struct XMedia: Decodable {
    let mediaKey: String
    let type: String
    let url: String?
    let previewImageURL: String?
    let width: Int?
    let height: Int?
    let altText: String?
}

private struct XEntities: Decodable {
    let urls: [XEntityURL]?
}

private struct XEntityURL: Decodable {
    let url: String
    let displayURL: String?
    let expandedURL: String?
    let title: String?
}

private struct XPublicMetrics: Decodable {
    let retweetCount: Int
    let replyCount: Int
    let likeCount: Int
    let quoteCount: Int
    let bookmarkCount: Int?
    let impressionCount: Int?
}

private struct XNoteTweet: Decodable {
    let text: String
}

private struct XAPIError: Decodable {
    let detail: String?
    let title: String?
}

private struct XErrorEnvelope: Decodable {
    let detail: String?
    let title: String?
}

