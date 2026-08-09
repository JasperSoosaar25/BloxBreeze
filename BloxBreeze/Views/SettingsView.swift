import SwiftUI

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

                Section {
                    Label("Active — no API key", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    LabeledContent("Cost", value: "Free")
                    LabeledContent("Accounts", value: "3")
                } header: {
                    Text("Free X delivery")
                } footer: {
                    Text("Public posts arrive through free, privacy-friendly Nitter RSS mirrors. No X login, developer account, API token, or subscription is needed. If one mirror is unavailable, BloxBreeze automatically tries another.")
                }

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
                    LabeledContent("Version", value: "1.1.0")
                    Label("Native Liquid Glass on iOS 26", systemImage: "circle.hexagongrid.fill")
                    Label("100% native article reader", systemImage: "text.document.fill")
                    Text("BloxBreeze is an independent reader. It is not endorsed by, affiliated with, or an official product of Roblox Corporation or X Corp.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Roblox Newsroom and Developer Forum articles are converted into native text and images. Public X posts are fetched from free RSS mirrors. The app contains no web browser, paid API, account system, or token field.")
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
                Text("Your source choices and saved-story list stay on this iPhone.")
            }
        }
    }
}
