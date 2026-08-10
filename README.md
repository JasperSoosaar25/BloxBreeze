# BloxBreeze

BloxBreeze is a zero-cost, native iPhone reader for Roblox news, built for iOS 26 with real SwiftUI Liquid Glass controls. Stories and supported source links are converted into SwiftUI text, lists, quotes, images, or native documents; the app does not contain an embedded web browser or send reading actions to Safari.

Sources included:

- Roblox Newsroom (official)
- Roblox Developer Forum announcements (official)
- `@Roblox_RTC` on X
- `@Bloxy_News` on X
- `@4Lulzy` on X

The three public X feeds arrive through free Nitter RSS mirrors. No X account, developer account, API key, bearer token, subscription, or app-owned server is required. Mirrors are tried automatically in order; because they are community-run services, X posts can be temporarily unavailable when every mirror is down.

## Features

- Native SwiftUI navigation, tab bar, sheets, forms, search, and iOS 26 Liquid Glass
- Native reader for Roblox Newsroom and Developer Forum text and images - no `WKWebView`
- Clean native X post view populated by free RSS, with link-preview clutter removed
- Self-reply and direct companion articles from RTC, Bloxy News, and 4Lulzy open in the native in-app reader
- Full-screen pinch/double-tap image zoom and native AVKit video playback
- Original-resolution DevForum and X images, animated GIF playback, retry fallbacks, and highest-bitrate available X video
- Pull to refresh, source filters, search, read/unread state, and offline feed cache
- Saved stories, gentle reading streak, light/dark mode, cozy color mode, Dynamic Type, and VoiceOver labels
- Original non-brand app icon and a clear independent-app disclaimer
- No analytics, ads, tracking, accounts, paid APIs, API keys, or app-owned backend

## Build the unsigned IPA on GitHub

This folder is ready for GitHub Actions because iOS apps must be compiled with Xcode on macOS. The workflow selects Xcode 26.6, chooses an iPhone simulator that actually exists on the runner, runs the unit tests, and packages an unsigned IPA for a signer such as KravaSigner.

1. Create a private GitHub repository and upload everything in this folder.
2. Open the repository's **Actions** tab.
3. Select **Build unsigned IPA**, choose **Run workflow**, and wait for the green check.
4. Open that workflow run and download the `BloxBreeze-unsigned-ipa` artifact.
5. Unzip the artifact once. Inside is `BloxBreeze-unsigned.ipa`.

If you have a Mac with Xcode 26.6, you can instead install XcodeGen, run `xcodegen generate`, and build the `BloxBreeze` scheme locally.

## Sign and install with KravaSigner

1. Move `BloxBreeze-unsigned.ipa` into the Files app on the iPhone.
2. In KravaSigner, import the IPA from Files.
3. Select a certificate/provisioning profile you are authorized to use and choose **Sign and Install**.
4. If the signer offers a bundle-ID override and your profile needs one, use a unique ID such as `com.yourname.bloxbreeze`.
5. Enable **Developer Mode** under **Settings > Privacy & Security** if iOS asks for it, then approve the developer profile under **Settings > General > VPN & Device Management** when applicable.

BloxBreeze itself has no subscription or paid service. Signing availability, device registration, and certificate revocation are controlled by Apple and the signing method, not by the app.

## How native reading works

- Roblox Newsroom HTML is downloaded and reduced to article headings, paragraphs, lists, quotes, and images.
- Developer Forum announcements use the forum's public JSON representation, then render the post as native SwiftUI blocks.
- X source pages are read from public RSS mirrors and rendered as native post cards. Supported article links in posts and self-replies are attached to their original card.
- Supported HTML sources are reduced to native article blocks, while PDF sources use PDFKit. Other URLs remain non-interactive plain text. There is no browser component or external URL opener in the target.

## Project notes

- App version: 1.5.0 (build 7)
- Deployment target: iOS 26.0
- Device family: iPhone
- Bundle identifier: `com.jasper.bloxbreeze` (safe to change in `project.yml`)
- Runtime dependency: SwiftSoup 2.13.5 (MIT-licensed Swift HTML parser)
- Network hosts: Roblox Newsroom/media, `devforum.roblox.com`, configured Nitter RSS mirrors, and only the supported companion-article/document hosts supplied by those feeds

Run the Windows-friendly static checks with:

```powershell
./scripts/Test-Project.ps1
```

## Independence and content

BloxBreeze is an independent reader and is not affiliated with, endorsed by, or an official product of Roblox Corporation, X Corp., or the Nitter project. Roblox, X, and the source-account names belong to their respective owners. Feed content remains attributable to its displayed source.
