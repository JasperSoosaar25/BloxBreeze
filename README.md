# BloxBreeze

BloxBreeze is a native iPhone news reader for Roblox stories, made for iOS 26 and its real SwiftUI Liquid Glass controls. It reads news inside the app and blocks link navigation in the article reader.

Sources included:

- Roblox Newsroom (official, works immediately)
- Roblox Developer Forum announcements (official, works immediately)
- `@Roblox_RTC` on X
- `@Bloxy_News` on X
- `@4Lulzy` on X

The X feeds use X's supported API. They require your own X developer bearer token; BloxBreeze stores it only in the iPhone Keychain. There is deliberately no shared secret in the IPA and no unofficial X scraper.

## Features

- Native SwiftUI navigation, tab bar, sheets, forms, search, and iOS 26 Liquid Glass
- In-app, link-disabled reader for complete Roblox and Developer Forum articles
- Native post reader for X text, media, and public metrics
- Pull to refresh, source filters, search, read/unread state, and offline cache
- Saved stories, gentle reading streak, light/dark mode, cozy color mode, Dynamic Type, and VoiceOver labels
- Original non-brand app icon and a clear independent-app disclaimer
- No analytics, ads, tracking, accounts, or app-owned backend

## Build the unsigned IPA on GitHub

This folder is ready for GitHub Actions because iOS apps must be compiled with Xcode on macOS. The workflow uses macOS 26 and Xcode 26.6, then packages an unsigned IPA specifically for a signer such as KravaSigner.

1. Create a private GitHub repository and upload everything in this folder.
2. Open the repository's **Actions** tab.
3. Select **Build unsigned IPA**, choose **Run workflow**, and wait for the green check.
4. Open that workflow run and download the `BloxBreeze-unsigned-ipa` artifact.
5. Unzip the artifact once. Inside is `BloxBreeze-unsigned.ipa`.

If you have a Mac with Xcode 26.6, you can instead install XcodeGen, run `xcodegen generate`, and build the `BloxBreeze` scheme locally.

## Sign and install with KravaSigner

1. Move `BloxBreeze-unsigned.ipa` into the Files app on the iPhone.
2. In KravaSigner, import the IPA from Files.
3. Select your valid certificate/provisioning profile and choose **Sign and Install**.
4. If KravaSigner offers a bundle-ID override and your profile needs one, use a unique ID such as `com.yourname.bloxbreeze`.
5. Enable **Developer Mode** under **Settings → Privacy & Security** if iOS asks for it, then approve the developer profile under **Settings → General → VPN & Device Management** when applicable.

Only use a certificate and provisioning profile you are authorized to use. Signing validity, device registration, and revocation are controlled by the certificate provider and Apple, not by BloxBreeze.

## Connect the three X sources

1. Create an X developer project/app at `https://developer.x.com` and obtain an app-only bearer token with read access.
2. Open **BloxBreeze → Settings → X connection**.
3. Paste the token and tap **Connect X sources**.

The app validates the token directly against `api.x.com`. Removing it deletes the Keychain entry. X access can be rate-limited, unavailable, or subject to the access tier attached to the developer account.

## Project notes

- Deployment target: iOS 26.0
- Device family: iPhone
- Bundle identifier: `com.jasper.bloxbreeze` (safe to change in `project.yml`)
- Runtime dependencies: none
- Network hosts: `about.roblox.com`, `corp.roblox.com`, `devforum.roblox.com`, `cms-media.roblox.com`, and `api.x.com`

Run the Windows-friendly static checks with:

```powershell
./scripts/Test-Project.ps1
```

## Independence and content

BloxBreeze is an independent reader and is not affiliated with, endorsed by, or an official product of Roblox Corporation or X Corp. Roblox, X, and the source-account names belong to their respective owners. Feed content remains attributable to its displayed source.

