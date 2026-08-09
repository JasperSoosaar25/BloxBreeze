import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: NewsStore
    @AppStorage("cozy-mode-v1") private var cozyMode = true
    @AppStorage("gentle-haptics-v1") private var gentleHaptics = true
    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $cozyMode) {
                        Label("Cozy colors", systemImage: "cup.and.heat.waves.fill")
                    }
                    Toggle(isOn: $gentleHaptics) {
                        Label("Gentle haptics", systemImage: "hand.tap.fill")
                    }
                } header: {
                    Text("Cozy corner")
                } footer: {
                    Text("BloxBreeze follows your iPhone’s light/dark mode and accessibility settings.")
                }

                Section("News sources") {
                    ForEach(NewsSource.all) { source in
                        Toggle(isOn: Binding(
                            get: { store.selectedSourceIDs.contains(source.id) },
                            set: { _ in store.toggleSource(source) }
                        )) {
                            Label {
                                VStack(alignment: .leading) {
                                    Text(source.name)
                                    Text(source.isOfficial ? "Official Roblox source" : "@\(source.handle ?? "") on X")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: source.symbol)
                                    .foregroundStyle(source.tint)
                            }
                        }
                    }
                }

                XConnectionSection()

                Section("Offline & privacy") {
                    LabeledContent("Cached stories", value: store.items.count.formatted())
                    if let updated = store.lastUpdated {
                        LabeledContent("Last updated", value: updated.formatted(date: .abbreviated, time: .shortened))
                    }
                    Button("Clear cached news", role: .destructive) {
                        showClearConfirmation = true
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    Label("Native Liquid Glass on iOS 26", systemImage: "circle.hexagongrid.fill")
                    Text("BloxBreeze is an independent reader. It is not endorsed by, affiliated with, or an official product of Roblox Corporation or X Corp.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("News is fetched directly from the Roblox Newsroom, the Roblox Developer Forum, and—when you connect it—the supported X API. BloxBreeze does not scrape X or send your token anywhere except api.x.com.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(BreezeBackground())
            .navigationTitle("Settings")
            .confirmationDialog("Clear downloaded news?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
                Button("Clear cache", role: .destructive) { store.clearCache() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your source choices and X token stay saved.")
            }
        }
    }
}

private struct XConnectionSection: View {
    @EnvironmentObject private var store: NewsStore
    @State private var token = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?
    @State private var showToken = false

    var body: some View {
        Section {
            if store.hasXToken {
                Label("X sources connected", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Button("Disconnect X", role: .destructive) {
                    do {
                        try store.removeXToken()
                        token = ""
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            } else {
                HStack {
                    Group {
                        if showToken {
                            TextField("Bearer token", text: $token)
                        } else {
                            SecureField("Bearer token", text: $token)
                        }
                    }
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                    Button {
                        showToken.toggle()
                    } label: {
                        Image(systemName: showToken ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showToken ? "Hide token" : "Show token")
                }

                Button {
                    connect()
                } label: {
                    if isConnecting {
                        HStack { ProgressView(); Text("Checking token…") }
                    } else {
                        Text("Connect X sources")
                    }
                }
                .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isConnecting)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                UIPasteboard.general.string = "https://developer.x.com"
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } label: {
                Label("Copy X developer portal address", systemImage: "doc.on.doc")
            }
        } header: {
            Text("X connection")
        } footer: {
            Text("X requires a developer bearer token for supported access to @Roblox_RTC, @Bloxy_News, and @4Lulzy. The token is kept in this iPhone’s Keychain and is never bundled in the app.")
        }
    }

    private func connect() {
        isConnecting = true
        errorMessage = nil
        Task {
            do {
                try await store.saveXToken(token)
                token = ""
            } catch {
                errorMessage = error.localizedDescription
            }
            isConnecting = false
        }
    }
}
