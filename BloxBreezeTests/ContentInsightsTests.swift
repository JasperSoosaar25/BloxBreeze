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

    func testProfileBioLinksAreSecureAndMentionsStayNative() throws {
        let text = "Congress nerds http://politico.com/congress and @politicomag."
        let matches = PostEntityExtractor.matches(in: text)

        XCTAssertEqual(matches.count, 2)
        XCTAssertEqual(matches[0].entity, .link(try XCTUnwrap(URL(string: "https://politico.com/congress"))))
        XCTAssertEqual(matches[1].entity, .mention("politicomag"))
        XCTAssertEqual(
            NativeLinkResolver.secure(try XCTUnwrap(URL(string: "http://politico.com"))).absoluteString,
            "https://politico.com"
        )
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
            "website": { "url": "http://politico.com", "display_url": "politico.com" },
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
        XCTAssertEqual(profile.websiteURL?.absoluteString, "https://politico.com")
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
        XCTAssertTrue(
            RobloxMarketplaceService.isMarketplaceURL(
                URL(string: "https://www.roblox.com/catalog?taxonomy=shared&SortType=4")!
            )
        )
        XCTAssertFalse(
            RobloxMarketplaceService.isMarketplaceURL(
                URL(string: "https://www.roblox.com/catalog/8276296168618/Sakura-Antlers")!
            )
        )
    }

    func testCollectibleCatalogDetailsPreferLiveResaleMarket() throws {
        let details = #"""
        {
          "Name": "Lord of the Buxeration",
          "Description": "The symbol of absolute wealth.",
          "ProductType": "User Product",
          "AssetTypeId": 8,
          "Creator": { "Id": 1, "Name": "Roblox", "HasVerifiedBadge": true },
          "PriceInRobux": 0,
          "IsForSale": false,
          "Sales": 0,
          "IsLimited": true,
          "IsLimitedUnique": false,
          "Remaining": 0,
          "Created": "2025-11-20T20:48:10.957Z",
          "Updated": "2026-08-15T12:00:00.000Z",
          "CollectiblesItemDetails": {
            "CollectibleLowestResalePrice": 8995,
            "IsForSale": false,
            "TotalQuantity": 100,
            "IsLimited": true
          }
        }
        """#
        let item = try RobloxCatalogService.parseForTesting(
            id: 87_983_592_197_138,
            fallbackName: "Fallback",
            detailsData: Data(details.utf8),
            favoriteData: Data("17872".utf8)
        )

        XCTAssertEqual(item.name, "Lord of the Buxeration")
        XCTAssertEqual(item.availability, .resale(lowestPrice: 8_995))
        XCTAssertEqual(item.favoriteCount, 17_872)
        XCTAssertEqual(item.totalQuantity, 100)
        XCTAssertEqual(item.assetTypeName, "Hat / accessory")
        XCTAssertTrue(item.isLimited)
        XCTAssertNotNil(item.createdAt)
    }

    func testSharedMarketplaceLinkBecomesNativeLiveCollection() throws {
        let search = #"""
        {
          "data": [
            {
              "id": 1001,
              "itemType": "Asset",
              "name": "Prism Skies",
              "description": "A cozy avatar background.",
              "creatorName": "Roblox",
              "creatorHasVerifiedBadge": true,
              "price": 0,
              "lowestResalePrice": 0,
              "priceStatus": "Free",
              "favoriteCount": 4321,
              "itemRestrictions": [],
              "taxonomy": [{ "taxonomyName": "Background" }]
            },
            {
              "id": 2002,
              "itemType": "Bundle",
              "name": "Not an asset",
              "itemRestrictions": []
            }
          ]
        }
        """#
        let thumbnails = #"""
        {
          "data": [{
            "targetId": 1001,
            "state": "Completed",
            "imageUrl": "https://tr.rbxcdn.com/example.png"
          }]
        }
        """#
        let sourceURL = try XCTUnwrap(
            URL(string: "https://www.roblox.com/catalog?taxonomy=shared&SortType=4&IncludeNotForSale=false")
        )
        let collection = try RobloxMarketplaceService.parseForTesting(
            sourceURL: sourceURL,
            searchData: Data(search.utf8),
            thumbnailData: Data(thumbnails.utf8)
        )

        XCTAssertEqual(collection.items.count, 1)
        XCTAssertEqual(collection.items[0].name, "Prism Skies")
        XCTAssertEqual(collection.items[0].taxonomyName, "Background")
        XCTAssertEqual(collection.items[0].marketLabel, "Free")
        XCTAssertEqual(collection.items[0].thumbnailURL?.host, "tr.rbxcdn.com")
        XCTAssertTrue(collection.filterLabels.contains("Shared collection"))
        XCTAssertTrue(collection.filterLabels.contains("Lowest price"))
        XCTAssertNotNil(collection.note)
    }
}
