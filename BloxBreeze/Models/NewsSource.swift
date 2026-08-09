import Foundation

struct NewsSource: Identifiable, Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case newsroom
        case developerForum
        case x
    }

    let id: String
    let name: String
    let handle: String?
    let kind: Kind
    let isOfficial: Bool
    let symbol: String

    static let robloxNewsroom = NewsSource(
        id: "roblox-newsroom",
        name: "Roblox Newsroom",
        handle: nil,
        kind: .newsroom,
        isOfficial: true,
        symbol: "checkmark.seal.fill"
    )

    static let developerForum = NewsSource(
        id: "roblox-developer-forum",
        name: "Creator Updates",
        handle: nil,
        kind: .developerForum,
        isOfficial: true,
        symbol: "hammer.fill"
    )

    static let robloxRTC = NewsSource(
        id: "x-roblox-rtc",
        name: "Roblox RTC",
        handle: "Roblox_RTC",
        kind: .x,
        isOfficial: false,
        symbol: "bubble.left.and.text.bubble.right.fill"
    )

    static let bloxyNews = NewsSource(
        id: "x-bloxy-news",
        name: "Bloxy News",
        handle: "Bloxy_News",
        kind: .x,
        isOfficial: false,
        symbol: "bolt.fill"
    )

    static let lulzy = NewsSource(
        id: "x-4lulzy",
        name: "4Lulzy",
        handle: "4Lulzy",
        kind: .x,
        isOfficial: false,
        symbol: "sparkles"
    )

    static let all: [NewsSource] = [
        .robloxNewsroom,
        .developerForum,
        .robloxRTC,
        .bloxyNews,
        .lulzy
    ]

    static let xSources: [NewsSource] = [.robloxRTC, .bloxyNews, .lulzy]

    static func source(forXHandle handle: String) -> NewsSource? {
        xSources.first { $0.handle?.caseInsensitiveCompare(handle) == .orderedSame }
    }
}

