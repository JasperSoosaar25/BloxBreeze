import XCTest
@testable import BloxBreeze

final class ContentInsightsTests: XCTestCase {
    func testPostEntitiesBecomeInternalRoutesWithoutLosingPunctuation() throws {
        let text = "Ask @HawleyMO about #Roblox, then read https://example.com/story."
        let matches = PostEntityExtractor.matches(in: text)
        let expectedURL = try XCTUnwrap(URL(string: "https://example.com/story"))

        XCTAssertEqual(matches.count, 3)
        XCTAssertEqual(matches[0].entity, .mention("HawleyMO"))
        XCTAssertEqual(matches[1].entity, .hashtag("Roblox"))
        XCTAssertEqual(matches[2].entity, .link(expectedURL))

        for match in matches {
            let deepLink = try XCTUnwrap(match.entity.route.deepLink)
            XCTAssertEqual(ContentEntityRoute(deepLink: deepLink), match.entity.route)
        }
    }

    @MainActor
    func testHashtagAndMentionCountsIncludeThreadReplies() throws {
        let defaults = UserDefaults.standard
        let cacheKey = "news-cache-v4"
        let previous = defaults.data(forKey: cacheKey)
        defer {
            if let previous {
                defaults.set(previous, forKey: cacheKey)
            } else {
                defaults.removeObject(forKey: cacheKey)
            }
        }

        let first = NewsItem(
            id: "thread-one",
            source: .robloxRTC,
            title: "#Roblox update",
            body: "A #Roblox update mentions @Builder.",
            category: nil,
            articleURL: nil,
            imageURL: nil,
            publishedAt: Date(timeIntervalSince1970: 10),
            metrics: nil,
            threadReplies: [
                XThreadReply(
                    id: "reply-one",
                    text: "More #roblox details from @Builder.",
                    publishedAt: Date(timeIntervalSince1970: 11),
                    articleURL: nil
                )
            ]
        )
        let second = NewsItem(
            id: "story-two",
            source: .bloxyNews,
            title: "Another update",
            body: "The community is talking about #ROBLOX.",
            category: nil,
            articleURL: nil,
            imageURL: nil,
            publishedAt: Date(timeIntervalSince1970: 12),
            metrics: nil
        )
        defaults.set(try JSONEncoder().encode([first, second]), forKey: cacheKey)

        let store = NewsStore()
        let stat = try XCTUnwrap(store.hashtagStats.first { $0.tag.caseInsensitiveCompare("Roblox") == .orderedSame })
        XCTAssertEqual(stat.postCount, 3)
        XCTAssertEqual(stat.storyCount, 2)
        XCTAssertEqual(stat.sourceCount, 2)
        XCTAssertEqual(store.items(matchingHashtag: "#roblox").count, 2)
        XCTAssertEqual(store.mentionPostCount(handle: "@builder"), 2)
        XCTAssertEqual(store.items(mentioning: "Builder").map(\.id), ["thread-one"])
    }

    func testKeylessProfilePayloadBecomesNativeProfile() throws {
        let profileJSON = #"""
        {
          "code": 200,
          "message": "OK",
          "user": {
            "screen_name": "politico",
            "followers": 5145580,
            "following": 1263,
            "statuses": 414563,
            "name": "POLITICO",
            "description": "Politics. Policy. Power.",
            "location": "Washington, D.C.",
            "banner_url": "https://pbs.twimg.com/profile_banners/9300262/1479760803",
            "avatar_url": "https://pbs.twimg.com/profile_images/example_normal.jpg",
            "joined": "Mon Oct 08 00:29:38 +0000 2007",
            "website": { "url": "https://politico.com", "display_url": "politico.com" },
            "verification": { "verified": true }
          }
        }
        """#
        let timelineJSON = #"""
        {
          "code": 200,
          "results": [{
            "id": "2088778461615943987",
            "text": "A recent public post",
            "replies": 2,
            "reposts": 3,
            "likes": 5,
            "views": 100,
            "created_at": "Sun Aug 16 00:02:47 +0000 2026",
            "created_timestamp": 1786838567
          }]
        }
        """#

        let profile = try XProfileService.parse(
            profileData: Data(profileJSON.utf8),
            timelineData: Data(timelineJSON.utf8)
        )

        XCTAssertEqual(profile.name, "POLITICO")
        XCTAssertEqual(profile.handle, "politico")
        XCTAssertTrue(profile.isVerified)
        XCTAssertEqual(profile.followers, 5_145_580)
        XCTAssertEqual(profile.avatarURL?.absoluteString, "https://pbs.twimg.com/profile_images/example_400x400.jpg")
        XCTAssertEqual(profile.recentPosts.map(\.id), ["2088778461615943987"])
        XCTAssertEqual(profile.recentPosts[0].views, 100)
    }

    func testRobloxCatalogAddressIsRecognized() {
        XCTAssertTrue(
            RobloxCatalogService.isCatalogURL(
                URL(string: "https://www.roblox.com/catalog/8276296168618/Sakura-Antlers")!
            )
        )
        XCTAssertFalse(
            RobloxCatalogService.isCatalogURL(
                URL(string: "https://www.roblox.com/games/123/Example")!
            )
        )
    }
}
