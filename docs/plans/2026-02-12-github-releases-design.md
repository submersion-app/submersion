# Multi-Platform GitHub Releases

## Summary

Implement a unified GitHub Actions release workflow that builds Submersion for all 5 target platforms (macOS, Windows, Linux, Android, iOS), creates a GitHub Release with downloadable artifacts, and uploads iOS and macOS builds to TestFlight/App Store via Fastlane.

## Trigger

Tag push matching `v*` (e.g., `v1.0.0`, `v1.1.0-beta.1`).

- Tags containing `-beta` or `-rc` create **pre-releases** on GitHub and trigger the `beta` Fastlane lane for iOS/macOS.
- Clean semver tags create **full releases** and trigger the `release` Fastlane lane.

## Architecture

```
Tag push (v1.2.0)
  -> [macOS job]    -> DMG (signed + notarized) + Mac App Store upload
  -> [Windows job]  -> ZIP
  -> [Linux job]    -> tar.gz
  -> [Android job]  -> APK (signed)
  -> [iOS job]      -> IPA + TestFlight/App Store upload
  -> [Release job]  -> Creates GitHub Release, attaches all artifacts
```

All platform jobs run in parallel on GitHub-hosted runners. The release job runs after all platform jobs complete.

## Runners

| Platform | Runner | Notes |
|----------|--------|-------|
| macOS | `macos-14` | Apple Silicon, free for public repos |
| Windows | `windows-latest` | Free for public repos |
| Linux | `ubuntu-latest` | Free for public repos |
| Android | `ubuntu-latest` | Free for public repos |
| iOS | `macos-14` | Free for public repos |

## Artifacts

| Platform | Artifact Name | Format |
|----------|--------------|--------|
| macOS | `Submersion-v1.2.0-macOS.dmg` | DMG (signed + notarized) |
| Windows | `Submersion-v1.2.0-Windows.zip` | ZIP of runner folder |
| Linux | `Submersion-v1.2.0-Linux.tar.gz` | tarball of bundle folder |
| Android | `Submersion-v1.2.0-Android.apk` | APK (release-signed) |
| iOS | `Submersion-v1.2.0-iOS.ipa` | IPA |

## Per-Platform Build Details

### macOS (signed + notarized + Mac App Store)

Two builds in a single job:

**Build 1 - GitHub DMG:**
1. `flutter build macos --release`
2. Codesign `.app` with Developer ID Application certificate
3. Create `.dmg` via `create-dmg`
4. Notarize via `xcrun notarytool`
5. Staple notarization ticket
6. Upload DMG artifact

**Build 2 - Mac App Store:**
1. Fastlane `sync_signing` (Match for macOS)
2. Fastlane `beta` or `release` lane (builds, signs with Mac App Store identity, uploads to TestFlight/App Store)

Uses existing `macos/Runner/Release.entitlements` for both builds (sandboxing already enabled).

### Windows (unsigned)

1. `flutter build windows --release`
2. ZIP `build/windows/x64/runner/Release/` directory
3. Upload artifact

### Linux (unsigned)

1. Install system deps (`libgtk-3-dev`, `libsqlite3-dev`, etc.)
2. `flutter build linux --release`
3. Tar `build/linux/x64/release/bundle/` directory
4. Upload artifact

### Android (signed)

1. Setup Java 17
2. Decode keystore from secrets
3. `flutter build apk --release` with signing config
4. Upload artifact

### iOS (signed + App Store)

1. Setup Flutter + Ruby
2. Setup App Store Connect API key
3. Determine lane from tag (beta vs release)
4. Sync code signing via Match
5. Build + sign via Fastlane (existing `ios/fastlane/Fastfile`)
6. Upload to TestFlight/App Store via Fastlane
7. Upload IPA artifact

### Create Release

Runs after all 5 build jobs complete:
1. Download all artifacts
2. Determine pre-release vs full release from tag
3. Create GitHub Release via `softprops/action-gh-release`
4. Attach all 5 platform artifacts
5. Auto-generate release notes from conventional commits

## Secrets

### Already Configured (from existing ios-release.yml)

| Secret | Used by |
|--------|---------|
| `APP_STORE_CONNECT_API_KEY_ID` | iOS, macOS |
| `APP_STORE_CONNECT_API_ISSUER_ID` | iOS, macOS |
| `APP_STORE_CONNECT_API_KEY_BASE64` | iOS, macOS |
| `MATCH_PASSWORD` | iOS, macOS |
| `MATCH_GIT_BASIC_AUTHORIZATION` | iOS, macOS |

### New Secrets Needed

| Secret | Used by | How to obtain |
|--------|---------|---------------|
| `MACOS_CERTIFICATE_BASE64` | macOS DMG signing | Export Developer ID Application cert from Keychain, base64 encode |
| `MACOS_CERTIFICATE_PASSWORD` | macOS DMG signing | Password set when exporting .p12 |
| `MACOS_KEYCHAIN_PASSWORD` | macOS CI keychain | Any arbitrary password |
| `APPLE_ID` | macOS notarization | Apple ID email |
| `APPLE_APP_PASSWORD` | macOS notarization | App-specific password from appleid.apple.com |
| `APPLE_TEAM_ID` | macOS notarization | `8U3RSKF42Q` |
| `ANDROID_KEYSTORE_BASE64` | Android signing | Base64-encoded release keystore |
| `ANDROID_KEYSTORE_PASSWORD` | Android signing | Keystore password |
| `ANDROID_KEY_ALIAS` | Android signing | Key alias |
| `ANDROID_KEY_PASSWORD` | Android signing | Key password |

## Files Changed/Created

| Action | File | Purpose |
|--------|------|---------|
| Create | `.github/workflows/release.yml` | Unified multi-platform release workflow |
| Create | `macos/fastlane/Fastfile` | macOS Fastlane lanes (build, beta, release) |
| Create | `macos/fastlane/Matchfile` | macOS Match configuration |
| Create | `macos/Gemfile` | Ruby/Fastlane dependencies for macOS |
| Retire | `.github/workflows/ios-release.yml` | Replaced by iOS job in release.yml |

## Developer Workflow

```bash
# 1. Update version in pubspec.yaml
#    version: 1.2.0+24

# 2. Commit the version bump
git commit -am "chore: bump version to 1.2.0"

# 3. Tag and push
git tag v1.2.0
git push origin main --tags

# 4. GitHub Actions builds all 5 platforms in parallel

# 5. GitHub Release is created automatically
#    with all artifacts + auto-generated release notes
```

## Release Notes

Auto-generated by GitHub from conventional commit messages and PR titles since the last tag. Works well with the project's `feat:`, `fix:`, `refactor:` commit format.

## Out of Scope

- Windows code signing (requires purchasing an EV code signing certificate)
- Linux package formats (Snap, Flatpak, AppImage) -- tar.gz only for now
- Android App Bundle (.aab) for Play Store -- APK only for now
- Automated version bumping (version is manually set in pubspec.yaml)
