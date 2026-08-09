import XCTest
@testable import BloxBreeze

final class RobloxFeedParsingTests: XCTestCase {
    func testNewsroomCardParsing() throws {
        let html = #"""
        <div class="grid">
          <a href="/newsroom/2026/08/a-soft-new-update" class="PreviewCard_preview-card__abc">
            <div><img src="https://cms-media.roblox.com/example.png" /></div>
            <h4 class="title PreviewCard_preview-card__eyebrow__abc">News</h4>
            <h3 class="title PreviewCard_preview-card__heading__abc">A Soft &amp; New Update</h3>
          </a>
        </div>
        """#

        let items = try RobloxNewsroomService.parse(html)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "A Soft & New Update")
        XCTAssertEqual(items[0].category, "News")
        XCTAssertEqual(items[0].source, .robloxNewsroom)
        XCTAssertEqual(items[0].imageURL?.absoluteString, "https://cms-media.roblox.com/example.png")
    }

    func testNewsroomParserDeduplicatesCards() throws {
        let card = #"""
        <a href="/newsroom/2026/08/repeated" class="PreviewCard_preview-card__abc">
          <h4 class="PreviewCard_preview-card__eyebrow__abc">Safety</h4>
          <h3 class="PreviewCard_preview-card__heading__abc">Repeated story</h3>
        </a>
        """#

        XCTAssertEqual(try RobloxNewsroomService.parse(card + card).count, 1)
    }

    func testDeveloperForumRSSParsing() throws {
        let xml = #"""
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
          <channel>
            <item>
              <title>Creator Update</title>
              <link>https://devforum.roblox.com/t/creator-update/123</link>
              <pubDate>Sun, 09 Aug 2026 10:30:00 +0000</pubDate>
              <category>Announcements</category>
              <description><![CDATA[<p>A useful <strong>official</strong> update.</p>]]></description>
            </item>
          </channel>
        </rss>
        """#

        let items = try DeveloperForumService.parse(Data(xml.utf8))

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].title, "Creator Update")
        XCTAssertEqual(items[0].body, "A useful official update.")
        XCTAssertEqual(items[0].source, .developerForum)
    }
}

