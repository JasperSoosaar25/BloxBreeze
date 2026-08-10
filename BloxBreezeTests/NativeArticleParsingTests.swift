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

    func testForumMediaUsesOriginalAssetAndDropsDiscourseMetadata() throws {
        let forumHTML = #"""
        <article>
          <h1>Native creator update</h1>
          <h2><img class="emoji" title=":hammer_and_wrench:" alt=":hammer_and_wrench:" src="/emoji.png"> Batching</h2>
          <ol><li>Set the property.<br>
            <div class="lightbox-wrapper"><a class="lightbox" href="//cdn.example.com/uploads/original/full.png">
              <img src="//cdn.example.com/uploads/optimized/full_2_690x75.png" alt="image3">
              <div class="meta"><span class="filename">image3</span><span class="informations">1204×132 12.3 KB</span></div>
            </a></div>
          </li></ol>
        </article>
        """#
        let html = ArticleContentService.normalizeForumEmojiImages(forumHTML)
        let item = NewsItem(
            id: "forum:media",
            source: .developerForum,
            title: "Native creator update",
            body: "Fallback",
            category: "Announcements",
            articleURL: URL(string: "https://devforum.roblox.com/t/native-update/123"),
            imageURL: nil,
            publishedAt: .now,
            metrics: nil
        )

        let article = try ArticleContentService.parseGenericArticle(html, item: item)

        XCTAssertTrue(article.blocks.contains { $0.kind == .heading && $0.text == "\u{1F6E0}\u{FE0F} Batching" })
        XCTAssertTrue(article.blocks.contains { $0.kind == .bullet && $0.text == "Set the property." })
        XCTAssertFalse(article.blocks.compactMap(\.text).contains { $0.contains("1204×132") || $0.contains("image3") })
        let media = try XCTUnwrap(article.blocks.first { $0.kind == .image })
        XCTAssertEqual(media.imageURL?.absoluteString, "https://cdn.example.com/uploads/original/full.png")
        XCTAssertNil(media.caption)
    }

    func testHighQualityMediaCandidatesPreferOrigins() {
        let nitter = URL(string: "https://nitter.net/pic/media%2Fcozy.jpg")!
        XCTAssertEqual(
            MediaImagePipeline.candidateURLs(for: nitter).first?.absoluteString,
            "https://pbs.twimg.com/media/cozy.jpg?name=orig"
        )

        let optimized = URL(string: "https://cdn.example.com/uploads/optimized/5X/a/b/hash_2_690x75.png")!
        XCTAssertEqual(
            MediaImagePipeline.candidateURLs(for: optimized).first?.absoluteString,
            "https://cdn.example.com/uploads/original/5X/a/b/hash.png"
        )
    }

    func testCompanionHTMLBecomesNativeArticle() throws {
        let html = #"""
        <html><head>
          <meta property="og:title" content="A Deeper Roblox Story">
          <meta property="og:description" content="The useful details behind the post.">
          <meta name="author" content="RTC Research">
          <meta property="og:image" content="/images/hero.png">
        </head><body><article>
          <h1>A Deeper Roblox Story</h1>
          <p>The article is converted into native SwiftUI text.</p>
          <h2>What it means</h2>
          <ul><li>No webpage is displayed.</li></ul>
          <img src="/images/detail.png" alt="Companion detail">
        </article></body></html>
        """#
        let item = NewsItem(
            id: "x:companion",
            source: .robloxRTC,
            title: "Fallback post title",
            body: "Fallback post body",
            category: "@Roblox_RTC",
            articleURL: URL(string: "https://robloxrtc.com/blog/deeper-story"),
            imageURL: nil,
            publishedAt: Date(timeIntervalSince1970: 1_786_243_800),
            metrics: nil
        )

        let article = try ArticleContentService.parseGenericArticle(html, item: item)

        XCTAssertEqual(article.title, "A Deeper Roblox Story")
        XCTAssertEqual(article.subtitle, "The useful details behind the post.")
        XCTAssertEqual(article.byline, "By RTC Research")
        XCTAssertEqual(article.heroImageURL?.absoluteString, "https://robloxrtc.com/images/hero.png")
        XCTAssertFalse(article.blocks.contains { $0.kind == .heading && $0.text == article.title })
        XCTAssertTrue(article.blocks.contains { $0.kind == .paragraph && $0.text?.contains("native SwiftUI") == true })
        XCTAssertTrue(article.blocks.contains { $0.kind == .image && $0.imageURL?.absoluteString == "https://robloxrtc.com/images/detail.png" })
    }
}
