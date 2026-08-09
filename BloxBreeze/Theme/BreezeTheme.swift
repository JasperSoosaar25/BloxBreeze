import SwiftUI

extension Color {
    static let breezeCoral = Color(red: 0.96, green: 0.34, blue: 0.48)
    static let breezeLavender = Color(red: 0.52, green: 0.46, blue: 0.96)
    static let breezePeach = Color(red: 1.00, green: 0.71, blue: 0.56)
    static let breezeMint = Color(red: 0.30, green: 0.76, blue: 0.68)
}

extension NewsSource {
    var tint: Color {
        switch id {
        case NewsSource.robloxNewsroom.id: return .breezeCoral
        case NewsSource.developerForum.id: return .breezeMint
        case NewsSource.robloxRTC.id: return .breezeLavender
        case NewsSource.bloxyNews.id: return .blue
        default: return .breezePeach
        }
    }
}

struct BreezeBackground: View {
    @AppStorage("cozy-mode-v1") private var cozyMode = true
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)

            LinearGradient(
                colors: cozyMode
                    ? [.breezeLavender.opacity(colorScheme == .dark ? 0.18 : 0.24), .breezePeach.opacity(0.16), .clear]
                    : [.blue.opacity(0.12), .cyan.opacity(0.08), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill((cozyMode ? Color.breezeCoral : .blue).opacity(colorScheme == .dark ? 0.08 : 0.11))
                .frame(width: 270, height: 270)
                .blur(radius: 70)
                .offset(x: 150, y: -310)
        }
        .ignoresSafeArea()
    }
}

extension View {
    @ViewBuilder
    func breezeGlass(cornerRadius: CGFloat = 24, tint: Color = .clear, interactive: Bool = false) -> some View {
        if interactive {
            glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            glassEffect(.regular.tint(tint), in: .rect(cornerRadius: cornerRadius))
        }
    }
}
