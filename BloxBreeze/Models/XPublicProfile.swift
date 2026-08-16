import Foundation

struct XPublicProfile: Hashable, Sendable {
    let handle: String
    let name: String
    let biography: String
    let location: String?
    let websiteURL: URL?
    let websiteLabel: String?
    let avatarURL: URL?
    let bannerURL: URL?
    let followers: Int
    let following: Int
    let postCount: Int
    let joinedAt: Date?
    let isVerified: Bool
    let recentPosts: [XProfilePost]
}

struct XProfilePost: Identifiable, Hashable, Sendable {
    let id: String
    let text: String
    let publishedAt: Date
    let replies: Int
    let reposts: Int
    let likes: Int
    let views: Int?
}

struct RobloxCatalogItem: Hashable, Sendable {
    let id: Int64
    let name: String
    let description: String?
    let creatorName: String?
    let creatorIsVerified: Bool
    let price: Int?
    let isForSale: Bool?
    let thumbnailURL: URL?
}
