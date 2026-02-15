# Auto-Update for Non-App Store Releases

## Summary

Implement automatic application updates for all non-store distribution channels (macOS DMG, Windows ZIP, Linux tar.gz, Android APK). App Store builds (iOS App Store, Mac App Store, future Play Store/MSIX/Snap) are excluded -- those stores handle their own updates.

## Approach

Hybrid: `auto_updater` package (Sparkle 2 + WinSparkle) for macOS and Windows, custom GitHub Releases API checker for Linux and Android.

## Architecture

```
+----------------------------------------------------+
|                  Submersion App                     |
|                                                     |
|  +-----------------------------------------------+ |
|  |            UpdateService (Dart)                | |
|  |  - Checks if update is available               | |
|  |  - Routes to platform-specific engine           | |
|  |  - Exposes Riverpod provider for UI             | |
|  +------------------+----------------------------+ |
|                     |                              |
|   +-----------------+------+  +------------------+ |
|   |    auto_updater        |  | GitHubUpdateEngine| |
|   |    (macOS/Windows)     |  | (Linux/Android)   | |
|   |    Sparkle 2           |  | GitHub Releases   | |
|   |    WinSparkle          |  | API + HTTP dl     | |
|   +----------+-------------+  +---------+--------+ |
|              |                          |           |
+--------------+--------------------------+-----------+
               |                          |
       +-------+--------+    +-----------+---------+
       |  appcast.xml   |    | GitHub Releases API |
       | (release asset)|    | /releases/latest    |
       +----------------+    +---------------------+
```

### Two Update Engines

1. **auto_updater (macOS + Windows)**: Wraps Sparkle 2 and WinSparkle. Reads an appcast.xml feed, downloads the update, verifies EdDSA/DSA signatures, and silently installs on restart. Call `autoUpdater.checkForUpdates()` on launch and the native framework handles everything.

2. **GitHubUpdateEngine (Linux + Android)**: Custom Dart service. Calls `GET https://api.github.com/repos/{owner}/{repo}/releases/latest`, parses the tag name to extract the version, compares with the running version (from `package_info_plus`). If newer: downloads the correct platform artifact, stores it locally, and shows an update-available banner via Riverpod state.

## Update Feed

### Appcast.xml (Sparkle/WinSparkle)

Hosted as a file attached to each GitHub Release. The feed URL:
```
https://github.com/{owner}/{repo}/releases/latest/download/appcast.xml
```

Structure:
```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Submersion Updates</title>
    <item>
      <title>Version 1.2.0</title>
      <sparkle:version>1.2.0</sparkle:version>
      <sparkle:shortVersionString>1.2.0</sparkle:shortVersionString>
      <sparkle:releaseNotesLink>
        https://github.com/{owner}/{repo}/releases/tag/v1.2.0
      </sparkle:releaseNotesLink>
      <pubDate>Sat, 14 Feb 2026 12:00:00 +0000</pubDate>
      <enclosure
        url="https://github.com/.../Submersion-v1.2.0-macOS.dmg"
        sparkle:edSignature="..."
        length="45000000"
        type="application/octet-stream"
        sparkle:os="macos"
      />
    </item>
  </channel>
</rss>
```

### GitHub Releases API (Linux/Android)

No feed file needed. The custom engine calls:
```
GET https://api.github.com/repos/{owner}/{repo}/releases/latest
```
Parses `tag_name` for version, `assets[]` for download URLs matching the platform suffix (`-Linux.tar.gz`, `-Android.apk`).

## CI/CD Changes

### New job in release.yml: `generate-appcast`

Runs after `build-macos` and `build-windows`, before `create-release`:

1. Download the macOS DMG and Windows ZIP artifacts
2. Sign them with EdDSA (macOS) and DSA (Windows) private keys
3. Generate `appcast.xml` with entries for both platforms
4. Upload `appcast.xml` as an artifact

### Modified: `create-release` job

Now also attaches `appcast.xml` to the GitHub Release.

### New job in release.yml: `generate-checksums`

Generates `checksums-sha256.txt` with SHA-256 hashes of all artifacts. Attached to the GitHub Release for Linux verification.

### Build flag for all platform jobs

Each `flutter build` command gets:
```
--dart-define=UPDATE_CHANNEL=github
```

### New Secrets

| Secret | Used by | How to obtain |
|--------|---------|---------------|
| `SPARKLE_EDDSA_PRIVATE_KEY` | macOS appcast signing | Sparkle's `generate_keys` tool |
| `WINSPARKLE_DSA_PRIVATE_KEY` | Windows appcast signing | OpenSSL DSA key generation |

## Distribution Channel Detection

Compile-time flag `UPDATE_CHANNEL` determines whether auto-update is active:

| Platform | Distribution | `UPDATE_CHANNEL` | Auto-update? |
|----------|-------------|-------------------|-------------|
| macOS DMG | GitHub Release | `github` | Yes (Sparkle) |
| macOS App Store | Mac App Store | `appstore` | No |
| iOS | App Store | `appstore` | No |
| Android APK | GitHub Release | `github` | Yes (GitHub API) |
| Android AAB | Google Play (future) | `playstore` | No |
| Windows ZIP | GitHub Release | `github` | Yes (WinSparkle) |
| Windows MSIX | Microsoft Store (future) | `msstore` | No |
| Linux tar.gz | GitHub Release | `github` | Yes (GitHub API) |
| Linux Snap/Flatpak | Snap Store (future) | `snapstore` | No |

Dart-side:
```dart
enum UpdateChannel { github, appstore, playstore, msstore, snapstore }

class UpdateChannelConfig {
  static const _raw = String.fromEnvironment('UPDATE_CHANNEL', defaultValue: 'github');
  static UpdateChannel get current => UpdateChannel.values.byName(_raw);
  static bool get isAutoUpdateEnabled => current == UpdateChannel.github;
}
```

Default is `github`, so local dev builds and all non-store binaries get auto-update by default. Store builds are explicitly opted out at compile time.

## Dart Code Structure

```
lib/features/auto_update/
  domain/
    entities/
      update_status.dart           # UpdateStatus sealed class
      update_info.dart             # Version, download URL, release notes, platform
      update_channel.dart          # UpdateChannel enum + config
  data/
    services/
      update_service.dart          # Abstract interface
      sparkle_update_service.dart  # macOS/Windows via auto_updater package
      github_update_service.dart   # Linux/Android via GitHub Releases API
  presentation/
    providers/
      update_providers.dart        # updateStatusProvider, updateServiceProvider
    widgets/
      update_banner.dart           # Persistent banner when update ready
      update_dialog.dart           # Dialog with release notes + progress
```

### UpdateStatus (sealed class)

```dart
sealed class UpdateStatus {
  const UpdateStatus();
}
class UpToDate extends UpdateStatus { const UpToDate(); }
class Checking extends UpdateStatus { const Checking(); }
class UpdateAvailable extends UpdateStatus {
  final String version;
  final String? releaseNotes;
  final String downloadUrl;
  const UpdateAvailable({required this.version, this.releaseNotes, required this.downloadUrl});
}
class Downloading extends UpdateStatus {
  final double progress; // 0.0 - 1.0
  const Downloading({required this.progress});
}
class ReadyToInstall extends UpdateStatus {
  final String version;
  final String localPath;
  const ReadyToInstall({required this.version, required this.localPath});
}
class UpdateError extends UpdateStatus {
  final String message;
  const UpdateError({required this.message});
}
```

## Update Check Behavior

- **On app launch:** Check once (with a 5-second delay to not block startup).
- **Periodic:** Every 4 hours while app is running (configurable in settings).
- **Manual:** Settings > About > "Check for Updates" button.
- **Conditional:** Skip entirely if `UpdateChannelConfig.isAutoUpdateEnabled` is false.

## UI Integration

### Update Banner

Slim Material 3 banner at the top of the main scaffold when update is in `ReadyToInstall` state:
- Text: "[version] available. Restart to update."
- Action button: "Restart Now"
- Dismissible per session (stored in memory, not persisted)

### Settings Page

Settings > About section:
- "Check for Updates" button with last check time and current version
- Toggle: "Automatic updates" (enabled by default). When disabled, the app still checks but only shows the banner -- no background download.

## Platform-Specific Installation

| Platform | Download | Install |
|----------|----------|---------|
| macOS | Sparkle handles everything | Sparkle replaces .app, prompts restart |
| Windows | WinSparkle handles everything | WinSparkle extracts, prompts restart |
| Linux | HTTP download tar.gz to temp dir | On restart: shell script moves new bundle over old, relaunches |
| Android | HTTP download APK to app cache | `Intent.ACTION_VIEW` opens system package installer |

## Security

- **macOS/Windows:** Sparkle 2 verifies EdDSA signatures on the downloaded update. Public key embedded in `Info.plist` (`SUPublicEDKey`). WinSparkle uses DSA. Signature verification failure rejects the update.
- **Linux:** SHA-256 checksum verification against `checksums-sha256.txt` from the release.
- **Android:** System package installer verifies APK signature matches the installed app (same signing key).
- **Rate limiting:** GitHub API has 60 req/hour unauthenticated limit. 4-hour check interval is well within this. Cache `ETag`/`Last-Modified` headers for conditional requests (304 Not Modified).
- **No secrets in app binary:** Only public keys are embedded. Private keys stay in CI secrets.

## Error Handling

- **Network failures during check:** Silently swallow, set state to `UpToDate`, retry at next interval.
- **Network failures during download:** Retry up to 3 times with exponential backoff, then set `UpdateError`.
- **Corrupted download:** Checksum mismatch triggers re-download (once), then `UpdateError`.
- **App Store builds:** Update system completely disabled via compile-time flag.

## Testing Strategy

- **Unit tests:** `GitHubUpdateService` with mocked HTTP client -- version comparison, asset URL parsing, error handling.
- **Widget tests:** `UpdateBanner` and `UpdateDialog` with mocked `updateStatusProvider` -- each state renders correctly.
- **Integration:** Manual testing of Sparkle/WinSparkle (document the manual test procedure).

## Dependencies

### New packages

| Package | Purpose | Platforms |
|---------|---------|-----------|
| `auto_updater` | Sparkle 2 + WinSparkle wrapper | macOS, Windows |
| `package_info_plus` | Get current app version at runtime | All |

### Existing packages used

| Package | Purpose |
|---------|---------|
| `http` | GitHub API calls, artifact download |
| `url_launcher` | Open release page in browser (fallback) |
| `shared_preferences` | Store last check time, auto-update preference |

## Out of Scope

- Delta/binary diff updates (Sparkle supports this but requires additional infrastructure)
- Rollback to previous version
- Update channels (beta/stable) -- all users get the latest release
- Windows code signing for the update (ZIP is unsigned; future MSIX would be signed)
- Automatic version bump in pubspec.yaml
