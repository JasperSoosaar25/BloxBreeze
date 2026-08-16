import Foundation

struct XProfileService: Sendable {
    func fetch(handle: String) async throws -> XPublicProfile {
        let cleanHandle = handle.trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        guard let encoded = cleanHandle.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let profileURL = URL(string: "https://api.fxtwitter.com/2/profile/\(encoded)"),
              let timelineURL = URL(string: "https://api.fxtwitter.com/2/profile/\(encoded)/statuses") else {
            throw FeedError.parsing("That profile handle could not be read.")
        }

        let profileData = try await fetchData(from: profileURL)
        let timelineData = try? await fetchData(from: timelineURL)
        return try Self.parse(profileData: profileData, timelineData: timelineData)
    }

    static func parse(profileData: Data, timelineData: Data?) throws -> XPublicProfile {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(ProfileResponse.self, from: profileData)
        guard response.code == 200, let user = response.user else {
            throw FeedError.parsing(response.message ?? "The public profile is unavailable.")
        }
        let timeline = timelineData.flatMap { try? decoder.decode(TimelineResponse.self, from: $0) }

        return XPublicProfile(
            handle: user.screenName,
            name: user.name,
            biography: user.description,
            location: user.location?.nonEmpty,
            websiteURL: user.website?.url
                .flatMap(URL.init(string:))
                .map(NativeLinkResolver.secure),
            websiteLabel: user.website?.displayUrl,
            avatarURL: highQualityAvatar(user.avatarUrl),
            bannerURL: user.bannerUrl.flatMap(URL.init(string:)),
            followers: user.followers,
            following: user.following,
            postCount: user.statuses,
            joinedAt: xDate(user.joined),
            isVerified: user.verification?.verified ?? false,
            recentPosts: (timeline?.results ?? []).prefix(12).map { post in
                XProfilePost(
                    id: post.id,
                    text: post.text,
                    publishedAt: post.createdTimestamp.map(Date.init(timeIntervalSince1970:)) ?? xDate(post.createdAt) ?? .distantPast,
                    replies: post.replies,
                    reposts: post.reposts,
                    likes: post.likes,
                    views: post.views
                )
            }
        )
    }

    private func fetchData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.cachePolicy = .returnCacheDataElseLoad
        request.setValue("BloxBreeze/1.7.1 (iOS; keyless native profile reader)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw FeedError.invalidResponse
        }
        return data
    }

    private static func highQualityAvatar(_ value: String?) -> URL? {
        guard let value else { return nil }
        let upgraded = value.replacingOccurrences(
            of: #"_(?:normal|mini|bigger)(?=\.[A-Za-z0-9]+(?:\?|$))"#,
            with: "_400x400",
            options: .regularExpression
        )
        return URL(string: upgraded)
    }

    private static func xDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE MMM dd HH:mm:ss Z yyyy"
        return formatter.date(from: value)
    }
}

private struct ProfileResponse: Decodable {
    let code: Int
    let message: String?
    let user: ProfileUser?
}

private struct ProfileUser: Decodable {
    let screenName: String
    let followers: Int
    let following: Int
    let statuses: Int
    let name: String
    let description: String
    let location: String?
    let bannerUrl: String?
    let avatarUrl: String?
    let joined: String?
    let website: ProfileWebsite?
    let verification: ProfileVerification?
}

private struct ProfileWebsite: Decodable {
    let url: String?
    let displayUrl: String?
}

private struct ProfileVerification: Decodable {
    let verified: Bool
}

private struct TimelineResponse: Decodable {
    let code: Int
    let results: [TimelinePost]
}

private struct TimelinePost: Decodable {
    let id: String
    let text: String
    let replies: Int
    let reposts: Int
    let likes: Int
    let createdAt: String?
    let createdTimestamp: Double?
    let views: Int?
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
