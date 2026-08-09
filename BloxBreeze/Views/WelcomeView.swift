import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            BreezeBackground()

            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "newspaper.fill")
                    .font(.system(size: 66, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 132, height: 132)
                    .glassEffect(.regular.tint(Color.breezeCoral).interactive(), in: .rect(cornerRadius: 34))
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text("BloxBreeze")
                        .font(.largeTitle.bold())
                    Text("Your soft little corner for Roblox news.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 18) {
                    WelcomeRow(symbol: "checkmark.seal.fill", color: Color.breezeCoral, title: "Official first", detail: "Roblox Newsroom and creator announcements work right away.")
                    WelcomeRow(symbol: "rectangle.stack.fill", color: Color.breezeLavender, title: "Actually native", detail: "Read clean text and images here - never an embedded webpage.")
                    WelcomeRow(symbol: "leaf.fill", color: Color.breezeMint, title: "Completely free", detail: "No paid API, subscription, account, or secret token needed.")
                    WelcomeRow(symbol: "heart.fill", color: Color.breezePeach, title: "Made cozy", detail: "Save stories, search everything, cache news, and keep a gentle reading streak.")
                }
                .padding(22)
                .breezeGlass(cornerRadius: 28, tint: .white.opacity(0.05))

                Spacer()

                Button(action: onContinue) {
                    Text("Make it breezy")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.glassProminent)

                Text("Independent reader · Not affiliated with Roblox or X")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }
}

private struct WelcomeRow: View {
    let symbol: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}
