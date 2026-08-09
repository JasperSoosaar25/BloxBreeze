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
        XCTAssertEqual(items[0].body, "Fresh Roblox update & cozy news\nEverything is readable here.")
        XCTAssertEqual(items[0].imageURL?.absoluteString, "https://pbs.twimg.com/media/example.jpg")
        XCTAssertNil(items[0].articleURL)
    }
}
