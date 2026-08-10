import XCTest
@testable import BloxBreeze

final class FreeXFeedParsingTests: XCTestCase {
    func testNitterRSSBecomesNativePost() throws {
        let xml = #"""
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
          <channel>
            <item>
              <title>Fresh Roblox update &amp; cozy news</title>
              <description><![CDATA[
                <p>Fresh Roblox update &amp; cozy news<br>Everything is readable here.</p>
                <img src="https://pbs.twimg.com/media/example.jpg" />
              ]]></description>
              <pubDate>Sun, 09 Aug 2026 10:30:00 GMT</pubDate>
              <guid>https://nitter.net/Roblox_RTC/status/123</guid>
            </item>
          </channel>
        </rss>
        """#

        let items = try FreeXFeedService.parse(Data(xml.utf8), source: .robloxRTC)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].source, .robloxRTC)
        XCTAssertEqual(items[0].body, "Fresh Roblox update & cozy news\n\nEverything is readable here.")
        XCTAssertEqual(items[0].imageURL?.absoluteString, "https://pbs.twimg.com/media/example.jpg")
        XCTAssertNil(items[0].articleURL)
    }

    func testRSSLinkPreviewDoesNotBecomePostBody() throws {
        let xml = #"""
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0"><channel><item>
          <title>Applications remain open https://devforum.roblox.com/t/example/123</title>
          <description><![CDATA[
            <p>Applications remain open until August 13th.<br><br>
            <a href="https://devforum.roblox.com/t/example/123">devforum.roblox.com/t/example...</a></p>
            <hr/><b>Link</b><br>
            <a href="https://devforum.roblox.com/t/example/123"><img src="https://nitter.net/pic/card.jpg"/><br><b>A very long preview title</b></a>
            <p>This preview paragraph must not be copied into the post.</p>
          ]]></description>
          <pubDate>Sun, 09 Aug 2026 10:30:00 GMT</pubDate>
          <guid>https://nitter.net/Roblox_RTC/status/456</guid>
        </item></channel></rss>
        """#

        let items = try FreeXFeedService.parse(Data(xml.utf8), source: .robloxRTC)

        XCTAssertEqual(items[0].body, "Applications remain open until August 13th.")
        XCTAssertFalse(items[0].body.contains("preview"))
    }

    func testSelfReplyArticleIsMergedIntoOriginalPost() throws {
        let xml = #"""
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0"><channel>
          <item>
            <title>Roblox is testing a cozy new creator feature.</title>
            <description><![CDATA[
              <p>Roblox is testing a cozy new creator feature.</p>
              <img src="https://pbs.twimg.com/media/original.jpg" />
            ]]></description>
            <pubDate>Sat, 08 Aug 2026 02:00:04 GMT</pubDate>
            <guid>2085908874994053302</guid>
          </item>
          <item>
            <title>R to @Roblox_RTC: Applications and complete details are available here.</title>
            <description><![CDATA[
              <p>Applications and complete details are available here.<br><br>
              <a href="https://devforum.roblox.com/t/cozy-creator-feature/4778993">devforum.roblox.com/t/cozy...</a></p>
            ]]></description>
            <pubDate>Sat, 08 Aug 2026 02:00:07 GMT</pubDate>
            <guid>2085908887266578904</guid>
          </item>
        </channel></rss>
        """#

        let items = try FreeXFeedService.parse(Data(xml.utf8), source: .robloxRTC)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].id, "x:2085908874994053302")
        XCTAssertEqual(
            items[0].articleURL?.absoluteString,
            "https://devforum.roblox.com/t/cozy-creator-feature/4778993"
        )
    }

    func testDirectArticleLinkIsKeptButActionLinksAreIgnored() throws {
        let xml = #"""
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0"><channel>
          <item>
            <title>A complete monthly recap.</title>
            <description><![CDATA[
              <p>A complete monthly recap.
              <a href="https://bloxy.news/post/july26">Read it</a></p>
            ]]></description>
            <pubDate>Sat, 01 Aug 2026 15:00:01 GMT</pubDate>
            <guid>2083568439503843798</guid>
          </item>
          <item>
            <title>A catalog item is now available.</title>
            <description><![CDATA[
              <p>A catalog item is now available.
              <a href="https://www.roblox.com/catalog/123/example">Get it</a></p>
            ]]></description>
            <pubDate>Fri, 31 Jul 2026 15:00:01 GMT</pubDate>
            <guid>2083568439503843799</guid>
          </item>
        </channel></rss>
        """#

        let items = try FreeXFeedService.parse(Data(xml.utf8), source: .bloxyNews)

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].articleURL?.absoluteString, "https://bloxy.news/post/july26")
        XCTAssertNil(items[1].articleURL)
    }

    func testStatusIDAndSyndicatedTextCleanup() {
        XCTAssertEqual(
            XPostDetailService.statusID(in: "x:https://nitter.net/Bloxy_News/status/2086215099573010915#m"),
            "2086215099573010915"
        )
        XCTAssertEqual(
            XPostDetailService.statusID(in: "x:2086215099573010915"),
            "2086215099573010915"
        )
        XCTAssertEqual(
            XPostDetailService.cleanPostText("A tidy post https://t.co/example"),
            "A tidy post"
        )
    }

    func testSyndicatedVideoDetailsBecomePlayableMedia() throws {
        let json = #"""
        {
          "text": "A native video post https://t.co/example",
          "mediaDetails": [{
            "type": "video",
            "media_url_https": "https://pbs.twimg.com/amplify_video_thumb/example.jpg",
            "original_info": { "height": 1920, "width": 1080 },
            "video_info": {
              "aspect_ratio": [9, 16],
              "variants": [
                { "content_type": "application/x-mpegURL", "url": "https://video.twimg.com/example.m3u8" },
                { "bitrate": 632000, "content_type": "video/mp4", "url": "https://video.twimg.com/small.mp4" },
                { "bitrate": 2176000, "content_type": "video/mp4", "url": "https://video.twimg.com/large.mp4" },
                { "bitrate": 8320000, "content_type": "video/mp4", "url": "https://video.twimg.com/original.mp4" }
              ]
            }
          }]
        }
        """#
        let item = NewsItem(
            id: "x:https://nitter.net/Bloxy_News/status/2086215099573010915#m",
            source: .bloxyNews,
            title: "Fallback",
            body: "Fallback body",
            category: "@Bloxy_News",
            articleURL: nil,
            imageURL: nil,
            publishedAt: .now,
            metrics: nil
        )

        let detail = try XPostDetailService.parse(Data(json.utf8), fallbackItem: item)

        XCTAssertEqual(detail.text, "A native video post")
        XCTAssertEqual(detail.media.count, 1)
        XCTAssertEqual(detail.media[0].kind, .video)
        XCTAssertEqual(detail.media[0].url.absoluteString, "https://video.twimg.com/original.mp4")
        XCTAssertEqual(detail.media[0].aspectRatio, 9.0 / 16.0)
    }
}
