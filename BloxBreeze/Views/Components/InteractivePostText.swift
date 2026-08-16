import SwiftUI
import UIKit

struct InteractivePostText: View {
    let text: String
    let onOpen: (ContentEntityRoute) -> Void

    var body: some View {
        Text(styledText)
            .font(.body)
            .lineSpacing(6)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.openURL, OpenURLAction { url in
                guard let route = ContentEntityRoute(deepLink: url) else { return .discarded }
                onOpen(route)
                return .handled
            })
            .contextMenu {
                Button {
                    UIPasteboard.general.string = text
                } label: {
                    Label("Copy post text", systemImage: "doc.on.doc")
                }
            }
            .accessibilityHint("Mentions, hashtags, and blue addresses open native BloxBreeze views")
    }

    private var styledText: AttributedString {
        let matches = PostEntityExtractor.matches(in: text)
        guard !matches.isEmpty else { return AttributedString(text) }

        var output = AttributedString()
        var cursor = text.startIndex
        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            if cursor < range.lowerBound {
                output.append(AttributedString(String(text[cursor..<range.lowerBound])))
            }

            var entityText = AttributedString(String(text[range]))
            entityText.foregroundColor = .blue
            entityText.inlinePresentationIntent = .stronglyEmphasized
            entityText.link = match.entity.route.deepLink
            output.append(entityText)
            cursor = range.upperBound
        }
        if cursor < text.endIndex {
            output.append(AttributedString(String(text[cursor...])))
        }
        return output
    }
}
