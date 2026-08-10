$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

$requiredFiles = @(
    'project.yml',
    'BloxBreeze/Info.plist',
    'BloxBreeze/Resources/PrivacyInfo.xcprivacy',
    'BloxBreeze/Resources/Assets.xcassets/AppIcon.appiconset/BloxBreezeIcon.png',
    'BloxBreeze/BloxBreezeApp.swift',
    'BloxBreeze/Services/FreeXFeedService.swift',
    'BloxBreeze/Services/ArticleContentService.swift',
    'BloxBreeze/Services/MediaImagePipeline.swift',
    'BloxBreeze/Services/XPostDetailService.swift',
    'BloxBreeze/Views/Components/NativeMediaViews.swift',
    '.github/workflows/build-unsigned-ipa.yml'
)

foreach ($relativePath in $requiredFiles) {
    $fullPath = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) {
        throw "Missing required file: $relativePath"
    }
}

$plistFiles = @(
    (Join-Path $root 'BloxBreeze/Info.plist'),
    (Join-Path $root 'BloxBreeze/Resources/PrivacyInfo.xcprivacy')
)
foreach ($plistPath in $plistFiles) {
    [xml](Get-Content -Raw -LiteralPath $plistPath) | Out-Null
}

Get-ChildItem -Path $root -Filter '*.json' -Recurse | ForEach-Object {
    Get-Content -Raw -LiteralPath $_.FullName | ConvertFrom-Json | Out-Null
}

$swift = Get-ChildItem -Path (Join-Path $root 'BloxBreeze') -Filter '*.swift' -Recurse
if ($swift.Count -lt 10) {
    throw "Expected at least 10 Swift source files, found $($swift.Count)."
}

$possibleSecrets = $swift | Select-String -Pattern 'Bearer\s+[A-Za-z0-9_-]{30,}'
if ($possibleSecrets) {
    throw 'A value resembling a hard-coded bearer token was found.'
}

$externalOpeners = $swift | Select-String -Pattern 'UIApplication\.shared\.open|openURL\(|SFSafariViewController'
if ($externalOpeners) {
    throw 'An external URL opener was found; stories must remain in the app.'
}

$browserCode = $swift | Select-String -Pattern 'import WebKit|WKWebView|ReaderWebView'
if ($browserCode) {
    throw 'An embedded browser was found; article content must use native SwiftUI views.'
}

$paidXFlow = $swift | Select-String -Pattern 'XAPIService|SecureTokenStore|api\.x\.com|developer\.x\.com'
if ($paidXFlow) {
    throw 'A paid/token-based X API flow was found; X sources must remain free and keyless.'
}

Add-Type -AssemblyName System.Drawing
$iconPath = Join-Path $root 'BloxBreeze/Resources/Assets.xcassets/AppIcon.appiconset/BloxBreezeIcon.png'
$icon = [System.Drawing.Image]::FromFile($iconPath)
try {
    if ($icon.Width -ne 1024 -or $icon.Height -ne 1024) {
        throw "The app icon must be 1024x1024, found $($icon.Width)x$($icon.Height)."
    }
    if ($icon.PixelFormat.ToString() -match 'Argb|PArgb') {
        throw 'The app icon must not contain an alpha channel.'
    }
} finally {
    $icon.Dispose()
}

Write-Host "BloxBreeze static checks passed ($($swift.Count) Swift files)."
