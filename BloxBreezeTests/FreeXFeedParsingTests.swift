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

    func testStatusIDAndSyndicatedTextCleanup() {
        XCTAssertEqual(
            XPostDetailService.statusID(in: "x:https://nitter.net/Bloxy_News/status/2086215099573010915#m"),
            "2086215099573010915"
        )
        XCTAssertEqual(
            XPostDetailService.cleanPostText("A tidy post https://t.co/example"),
            "A tidy post"
        )
    }
}
