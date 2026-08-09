import XCTest
@testable import BloxBreeze

final class NativeArticleParsingTests: XCTestCase {
    func testNewsroomHTMLBecomesNativeBlocks() throws {
        let html = #"""
        <article>
          <h1>A Native Roblox Story</h1>
          <div class="NewsArticle_news__text-group__abc"><p class="body--large">A gentle summary.</p></div>
          <div class="NewsArticle_news__byline__abc"><p>By Roblox</p></div>
          <div class="NewsArticle_news__content__abc">
            <h2>What changed</h2>
            <p>The complete article is rendered without a webpage.</p>
            <ul><li>First native detail</li><li>Second native detail</li></ul>
            <blockquote>A useful quote.</blockquote>
            <img src="/images/detail.png" alt="Update preview" />
          </div>
        </article>
        """#
        let item = NewsItem(
            id: "newsroom:test",
            source: .robloxNewsroom,
            title: "Fallback title",
            body: "Fallback summary",
            category: "News",
            articleURL: URL(string: "https://about.roblox.com/newsroom/2026/08/native-story"),
            imageURL: nil,
            publishedAt: Date(timeIntervalSince1970: 1_786_243_800),
            metrics: nil
        )

        let article = try ArticleContentService.parseNewsroom(html, item: item)

        XCTAssertEqual(article.title, "A Native Roblox Story")
        XCTAssertEqual(article.subtitle, "A gentle summary.")
        XCTAssertEqual(article.byline, "By Roblox")
        XCTAssertTrue(article.blocks.contains { $0.kind == .heading && $0.text == "What changed" })
        XCTAssertEqual(article.blocks.filter { $0.kind == .bullet }.count, 2)
        XCTAssertTrue(article.blocks.contains { $0.kind == .quote && $0.text == "A useful quote." })
        XCTAssertTrue(article.blocks.contains { $0.kind == .image && $0.imageURL?.absoluteString == "https://about.roblox.com/images/detail.png" })
    }

    func testForumEmojiImageBecomesUnicode() {
        let html = #"""
        <p>A cozy update <img src="/images/emoji/twitter/star2.png" class="emoji" title=":star2:" alt=":star2:" width="20" height="20"> today.</p>
        <img src="https://cdn.example.com/full-size-story.png" alt="Story art">
        """#

        let normalized = ArticleContentService.normalizeForumEmojiImages(html)

        XCTAssertTrue(normalized.contains("A cozy update 🌟 today."))
        XCTAssertTrue(normalized.contains("full-size-story.png"))
        XCTAssertFalse(normalized.contains(":star2:"))
    }
}
